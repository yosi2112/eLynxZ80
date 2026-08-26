/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex
	Date   : 2026.05.20-

	[ SIO-A external serial bridge ]
*/

#ifndef _LYNXZ80_SERIAL_H_
#define _LYNXZ80_SERIAL_H_

#include "../vm.h"
#include "../../emu.h"
#include "../device.h"

#ifdef _WIN32
#include <windows.h>
#endif

class Z80SIO;

#define SIG_SERIAL_SIOA_TX	0

class SERIAL : public DEVICE
{
private:
	enum Mode {
		MODE_NONE,
		MODE_SOCKET,
		MODE_COM
	};

	Z80SIO* d_sio;
	Mode mode;
	int configured_type;
	bool socket_connected;
	uint8_t socket_send_buffer[1024];
	int socket_send_r;
	int socket_send_w;
	uint8_t socket_recv_buffer[1024];

#ifdef _WIN32
	HANDLE com_handle;
	SOCKET listen_socket;
	SOCKET active_socket;
#endif

	void close_backend();
	bool configure_from_config();
	bool configure_socket(const char* spec);
	bool configure_com(const char* spec);
	void enqueue_socket_send(uint8_t data);
	void flush_socket_send();
	void receive_byte(uint8_t data);
	static bool parse_ipv4(const char* text, uint32_t* value);

public:
	SERIAL(VM_TEMPLATE* parent_vm, EMU* parent_emu) : DEVICE(parent_vm, parent_emu)
	{
		d_sio = NULL;
		mode = MODE_NONE;
		configured_type = -1;
		socket_connected = false;
		socket_send_r = socket_send_w = 0;
#ifdef _WIN32
		com_handle = INVALID_HANDLE_VALUE;
		listen_socket = INVALID_SOCKET;
		active_socket = INVALID_SOCKET;
#endif
		set_device_name(_T("SIO-A External Serial"));
	}
	~SERIAL() {}

	void initialize();
	void release();
	void reset();
	void update_config();
	void event_callback(int event_id, int err);
	void write_signal(int id, uint32_t data, uint32_t mask);
	bool process_state(FILEIO* state_fio, bool loading);

	void set_context_sio(Z80SIO* device)
	{
		d_sio = device;
	}

	void notify_socket_connected(int ch);
	void notify_socket_disconnected(int ch);
	uint8_t* get_socket_send_buffer(int ch, int* size);
	void inc_socket_send_buffer_ptr(int ch, int size);
	uint8_t* get_socket_recv_buffer0(int ch, int* size0, int* size1);
	uint8_t* get_socket_recv_buffer1(int ch);
	void inc_socket_recv_buffer_ptr(int ch, int size);
};

#endif
