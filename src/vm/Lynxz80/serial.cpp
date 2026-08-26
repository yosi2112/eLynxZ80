/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex
	Date   : 2026.05.20-

	[ SIO-A external serial bridge ]
*/

#include "serial.h"
#include "../z80sio.h"
#include "../../config.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

namespace {
constexpr int EVENT_SERIAL_POLL = 0;
constexpr double POLL_USEC = 2000.0;
constexpr double DEFAULT_BAUD_CLOCK = 9600.0 * 16.0;

static const char* const kSerialSpecs[] = {
	"off",
	"com:COM1:9600",
	"com:COM2:9600",
	"com:COM3:9600",
	"com:COM4:9600",
	"tcp:127.0.0.1:8023",
};
}

void SERIAL::initialize()
{
	configure_from_config();
	register_event(this, EVENT_SERIAL_POLL, POLL_USEC, true, NULL);
}

void SERIAL::release()
{
	close_backend();
}

void SERIAL::reset()
{
	socket_send_r = socket_send_w = 0;
	if(d_sio != NULL) {
		d_sio->set_context_send(0, this, SIG_SERIAL_SIOA_TX);
		d_sio->set_tx_clock(0, DEFAULT_BAUD_CLOCK);
		d_sio->set_rx_clock(0, DEFAULT_BAUD_CLOCK);
		d_sio->write_signal(SIG_Z80SIO_DCD_CH0, 0, 1);
		d_sio->write_signal(SIG_Z80SIO_CTS_CH0, 0, 1);
	}
}

void SERIAL::update_config()
{
	configure_from_config();
}

void SERIAL::event_callback(int event_id, int err)
{
	(void)err;
	if(event_id != EVENT_SERIAL_POLL) {
		return;
	}
#ifdef _WIN32
	if(mode == MODE_SOCKET) {
		if(active_socket == INVALID_SOCKET && listen_socket != INVALID_SOCKET) {
			struct sockaddr_in from;
			int from_len = sizeof(from);
			SOCKET accepted = accept(listen_socket, reinterpret_cast<struct sockaddr*>(&from), &from_len);
			if(accepted != INVALID_SOCKET) {
				unsigned long nonblock = 1;
				ioctlsocket(accepted, FIONBIO, &nonblock);
				active_socket = accepted;
				socket_connected = true;
				flush_socket_send();
			}
		}
		if(active_socket != INVALID_SOCKET) {
			char data[64];
			int read_size = recv(active_socket, data, sizeof(data), 0);
			if(read_size > 0) {
				for(int i = 0; i < read_size; i++) {
					receive_byte(static_cast<uint8_t>(data[i]));
				}
			} else if(read_size == 0 || WSAGetLastError() == WSAECONNRESET) {
				closesocket(active_socket);
				active_socket = INVALID_SOCKET;
				socket_connected = false;
			}
			flush_socket_send();
		}
	}
	if(mode == MODE_COM && com_handle != INVALID_HANDLE_VALUE) {
		uint8_t data[64];
		DWORD read_size = 0;
		if(ReadFile(com_handle, data, sizeof(data), &read_size, NULL)) {
			for(DWORD i = 0; i < read_size; i++) {
				receive_byte(data[i]);
			}
		}
	}
#endif
}

void SERIAL::write_signal(int id, uint32_t data, uint32_t mask)
{
	if(id != SIG_SERIAL_SIOA_TX) {
		return;
	}
	uint8_t value = static_cast<uint8_t>(data & mask);
	if(mode == MODE_SOCKET) {
		enqueue_socket_send(value);
		flush_socket_send();
		return;
	}
#ifdef _WIN32
	if(mode == MODE_COM && com_handle != INVALID_HANDLE_VALUE) {
		DWORD written = 0;
		WriteFile(com_handle, &value, 1, &written, NULL);
	}
#endif
}

void SERIAL::close_backend()
{
#ifdef _WIN32
	if(mode == MODE_SOCKET) {
		if(active_socket != INVALID_SOCKET) {
			shutdown(active_socket, 2);
			closesocket(active_socket);
			active_socket = INVALID_SOCKET;
		}
		if(listen_socket != INVALID_SOCKET) {
			closesocket(listen_socket);
			listen_socket = INVALID_SOCKET;
		}
	}
#endif
#ifdef _WIN32
	if(com_handle != INVALID_HANDLE_VALUE) {
		CloseHandle(com_handle);
		com_handle = INVALID_HANDLE_VALUE;
	}
#endif
	mode = MODE_NONE;
	socket_connected = false;
}

bool SERIAL::configure_from_config()
{
	if(config.serial_type == configured_type) {
		return mode != MODE_NONE;
	}
	close_backend();
	configured_type = config.serial_type;
	if(configured_type < 0 ||
	   configured_type >= static_cast<int>(sizeof(kSerialSpecs) / sizeof(kSerialSpecs[0]))) {
		return false;
	}
	const char* spec = kSerialSpecs[configured_type];
	if(strcmp(spec, "off") == 0) {
		return false;
	}
	if(strncmp(spec, "tcp:", 4) == 0 || strncmp(spec, "ip:", 3) == 0) {
		if(configure_socket(spec)) {
			return true;
		}
		configured_type = -1;
		return false;
	}
	if(strncmp(spec, "com:", 4) == 0 || strncmp(spec, "COM", 3) == 0) {
		if(configure_com(spec)) {
			return true;
		}
		configured_type = -1;
		return false;
	}
	return false;
}

bool SERIAL::configure_socket(const char* spec)
{
#ifdef _WIN32
	const char* endpoint = strchr(spec, ':');
	if(endpoint == NULL) {
		return false;
	}
	endpoint++;
	char host[64];
	const char* colon = strrchr(endpoint, ':');
	if(colon == NULL || colon == endpoint) {
		return false;
	}
	size_t host_len = static_cast<size_t>(colon - endpoint);
	if(host_len >= sizeof(host)) {
		return false;
	}
	memcpy(host, endpoint, host_len);
	host[host_len] = '\0';
	int port = atoi(colon + 1);
	uint32_t ipaddr = 0;
	if(port <= 0 || !parse_ipv4(host, &ipaddr)) {
		return false;
	}
	listen_socket = socket(PF_INET, SOCK_STREAM, 0);
	if(listen_socket == INVALID_SOCKET) {
		return false;
	}
	unsigned long nonblock = 1;
	ioctlsocket(listen_socket, FIONBIO, &nonblock);
	BOOL reuse = TRUE;
	setsockopt(listen_socket, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&reuse), sizeof(reuse));
	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = ipaddr;
	addr.sin_port = htons(static_cast<unsigned short>(port));
	if(bind(listen_socket, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) == SOCKET_ERROR) {
		closesocket(listen_socket);
		listen_socket = INVALID_SOCKET;
		return false;
	}
	if(listen(listen_socket, 1) == SOCKET_ERROR) {
		closesocket(listen_socket);
		listen_socket = INVALID_SOCKET;
		return false;
	}
	mode = MODE_SOCKET;
	socket_send_r = socket_send_w = 0;
	return true;
#else
	(void)spec;
	return false;
#endif
}

bool SERIAL::configure_com(const char* spec)
{
#ifdef _WIN32
	const char* name = strncmp(spec, "com:", 4) == 0 ? spec + 4 : spec;
	char port_name[64];
	int baud = 9600;
	const char* colon = strchr(name, ':');
	size_t name_len = colon != NULL ? static_cast<size_t>(colon - name) : strlen(name);
	if(name_len == 0 || name_len >= 16) {
		return false;
	}
	if(colon != NULL) {
		baud = atoi(colon + 1);
		if(baud <= 0) {
			baud = 9600;
		}
	}
	snprintf(port_name, sizeof(port_name), "\\\\.\\%.*s", static_cast<int>(name_len), name);
	com_handle = CreateFileA(port_name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
	if(com_handle == INVALID_HANDLE_VALUE) {
		return false;
	}
	DCB dcb;
	memset(&dcb, 0, sizeof(dcb));
	dcb.DCBlength = sizeof(dcb);
	if(!GetCommState(com_handle, &dcb)) {
		close_backend();
		return false;
	}
	dcb.BaudRate = baud;
	dcb.ByteSize = 8;
	dcb.Parity = NOPARITY;
	dcb.StopBits = ONESTOPBIT;
	dcb.fBinary = TRUE;
	dcb.fDtrControl = DTR_CONTROL_ENABLE;
	dcb.fRtsControl = RTS_CONTROL_ENABLE;
	if(!SetCommState(com_handle, &dcb)) {
		close_backend();
		return false;
	}
	COMMTIMEOUTS timeouts;
	memset(&timeouts, 0, sizeof(timeouts));
	timeouts.ReadIntervalTimeout = MAXDWORD;
	timeouts.ReadTotalTimeoutMultiplier = 0;
	timeouts.ReadTotalTimeoutConstant = 0;
	timeouts.WriteTotalTimeoutMultiplier = 0;
	timeouts.WriteTotalTimeoutConstant = 100;
	SetCommTimeouts(com_handle, &timeouts);
	mode = MODE_COM;
	return true;
#else
	(void)spec;
	return false;
#endif
}

void SERIAL::enqueue_socket_send(uint8_t data)
{
	int next_w = (socket_send_w + 1) % static_cast<int>(sizeof(socket_send_buffer));
	if(next_w == socket_send_r) {
		socket_send_r = (socket_send_r + 1) % static_cast<int>(sizeof(socket_send_buffer));
	}
	socket_send_buffer[socket_send_w] = data;
	socket_send_w = next_w;
}

void SERIAL::flush_socket_send()
{
#ifdef _WIN32
	while(mode == MODE_SOCKET && active_socket != INVALID_SOCKET && socket_send_r != socket_send_w) {
		int available = socket_send_w >= socket_send_r ?
			socket_send_w - socket_send_r :
			static_cast<int>(sizeof(socket_send_buffer)) - socket_send_r;
		int sent = send(active_socket, reinterpret_cast<const char*>(&socket_send_buffer[socket_send_r]), available, 0);
		if(sent == SOCKET_ERROR) {
			int error = WSAGetLastError();
			if(error != WSAEWOULDBLOCK) {
				closesocket(active_socket);
				active_socket = INVALID_SOCKET;
				socket_connected = false;
			}
			return;
		}
		if(sent <= 0) {
			return;
		}
		socket_send_r = (socket_send_r + sent) % static_cast<int>(sizeof(socket_send_buffer));
	}
#endif
}

void SERIAL::receive_byte(uint8_t data)
{
	if(d_sio != NULL) {
		d_sio->write_signal(SIG_Z80SIO_RECV_CH0, data, 0xff);
	}
}

bool SERIAL::parse_ipv4(const char* text, uint32_t* value)
{
	unsigned int b[4];
	char tail;
	if(sscanf(text, "%u.%u.%u.%u%c", &b[0], &b[1], &b[2], &b[3], &tail) != 4) {
		return false;
	}
	for(int i = 0; i < 4; i++) {
		if(b[i] > 255) {
			return false;
		}
	}
	*value = (b[0] << 0) | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);
	return true;
}

void SERIAL::notify_socket_connected(int ch)
{
	if(ch == 0) {
		socket_connected = true;
	}
}

void SERIAL::notify_socket_disconnected(int ch)
{
	if(ch == 0) {
		socket_connected = false;
	}
}

uint8_t* SERIAL::get_socket_send_buffer(int ch, int* size)
{
	if(size != NULL) {
		*size = 0;
	}
	if(ch != 0 || mode != MODE_SOCKET || socket_send_r == socket_send_w) {
		return NULL;
	}
	int available = socket_send_w >= socket_send_r ?
		socket_send_w - socket_send_r :
		static_cast<int>(sizeof(socket_send_buffer)) - socket_send_r;
	if(size != NULL) {
		*size = available;
	}
	return &socket_send_buffer[socket_send_r];
}

void SERIAL::inc_socket_send_buffer_ptr(int ch, int size)
{
	if(ch == 0 && size > 0) {
		socket_send_r = (socket_send_r + size) % static_cast<int>(sizeof(socket_send_buffer));
	}
}

uint8_t* SERIAL::get_socket_recv_buffer0(int ch, int* size0, int* size1)
{
	if(size0 != NULL) {
		*size0 = (ch == 0 && mode == MODE_SOCKET) ? static_cast<int>(sizeof(socket_recv_buffer)) : 0;
	}
	if(size1 != NULL) {
		*size1 = 0;
	}
	return (ch == 0 && mode == MODE_SOCKET) ? socket_recv_buffer : NULL;
}

uint8_t* SERIAL::get_socket_recv_buffer1(int ch)
{
	(void)ch;
	return socket_recv_buffer;
}

void SERIAL::inc_socket_recv_buffer_ptr(int ch, int size)
{
	if(ch != 0 || size <= 0) {
		return;
	}
	for(int i = 0; i < size; i++) {
		receive_byte(socket_recv_buffer[i]);
	}
}

#define STATE_VERSION	1

bool SERIAL::process_state(FILEIO* state_fio, bool loading)
{
	if(!state_fio->StateCheckUint32(STATE_VERSION)) {
		return false;
	}
	if(!state_fio->StateCheckInt32(this_device_id)) {
		return false;
	}
	state_fio->StateValue(socket_send_r);
	state_fio->StateValue(socket_send_w);
	state_fio->StateArray(socket_send_buffer, sizeof(socket_send_buffer), 1);
	if(loading) {
		if(socket_send_r < 0 || socket_send_r >= static_cast<int>(sizeof(socket_send_buffer)) ||
		   socket_send_w < 0 || socket_send_w >= static_cast<int>(sizeof(socket_send_buffer))) {
			socket_send_r = socket_send_w = 0;
		}
	}
	return true;
}
