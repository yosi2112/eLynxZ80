/*
	Lynx Z80 Emulator

	Author : OpenAI Codex
	Date   : 2026.05.08-

	[ keyboard ]
*/

#include "keyboard.h"
#include "../z80sio.h"
#include "probe_log.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

namespace {

static bool pressed(const uint8_t* key_stat, int code)
{
	return key_stat != NULL && key_stat[code & 0xff] != 0;
}

#ifdef _DEBUG
static int keyboard_probe_log_count = 0;

static void keyboard_probe_log(const char* format, ...)
{
	va_list args;
	va_start(args, format);
	probe_log_write("lynxz80_keyboard.log", keyboard_probe_log_count, format, args);
	va_end(args);
}
#else
static inline void keyboard_probe_log(const char* format, ...) { (void)format; }
#endif

}

void KEYBOARD::initialize()
{
	key_stat = emu->get_key_buffer();
}

void KEYBOARD::reset()
{
	kana = false;
	caps = false;
	clear_fifo();
}

bool KEYBOARD::is_shifted() const
{
	return pressed(key_stat, VK_SHIFT);
}

bool KEYBOARD::is_controlled() const
{
	return pressed(key_stat, VK_CONTROL);
}

int KEYBOARD::translate_key(int code) const
{
	bool shift = is_shifted();
	bool ctrl = is_controlled();

	if(code >= 'A' && code <= 'Z') {
		if(ctrl) {
			return code - 'A' + 1;
		}
		bool upper = caps ^ shift;
		return (upper ? 'A' : 'a') + (code - 'A');
	}
	if(code >= '0' && code <= '9') {
		static const char shifted_digits[] = ")!@#$%^&*(";
		return shift ? shifted_digits[code - '0'] : code;
	}
	if(code >= VK_NUMPAD0 && code <= VK_NUMPAD9) {
		return '0' + (code - VK_NUMPAD0);
	}

	switch(code) {
	case VK_BACK:
		return 0x08;	// BS
	case VK_TAB:
		return 0x09;	// HT
	case VK_RETURN:
		return 0x0d;	// CR
	case VK_ESCAPE:
		return 0x1b;	// ESC
	case VK_SPACE:
		return ctrl ? 0x00 : 0x20;
	case VK_DELETE:
		return 0x7f;	// DEL
	case VK_MULTIPLY:
		return '*';
	case VK_ADD:
		return '+';
	case VK_SUBTRACT:
		return '-';
	case VK_DECIMAL:
		return '.';
	case VK_DIVIDE:
		return '/';
	case VK_OEM_1:
		return shift ? ':' : ';';
	case VK_OEM_PLUS:
		return shift ? '+' : '=';
	case VK_OEM_COMMA:
		return shift ? '<' : ',';
	case VK_OEM_MINUS:
		return shift ? '_' : '-';
	case VK_OEM_PERIOD:
		return shift ? '>' : '.';
	case VK_OEM_2:
		if(ctrl) {
			return 0x7f;
		}
		return shift ? '?' : '/';
	case VK_OEM_3:
		return shift ? '~' : '`';
	case VK_OEM_4:
		return ctrl ? 0x1b : (shift ? '{' : '[');
	case VK_OEM_5:
		return ctrl ? 0x1c : (shift ? '|' : '\\');
	case VK_OEM_6:
		return ctrl ? 0x1d : (shift ? '}' : ']');
	case VK_OEM_7:
		return shift ? '"' : '\'';
	case VK_OEM_102:
		return ctrl ? 0x1f : (shift ? '_' : '\\');
	}
	return -1;
}

void KEYBOARD::clear_fifo()
{
	memset(fifo, 0, sizeof(fifo));
	fifo_r = 0;
	fifo_w = 0;
	fifo_count = 0;
}

void KEYBOARD::enqueue(uint8_t data)
{
	data &= 0x7f;
	if(fifo_count >= (int)sizeof(fifo)) {
		fifo_r = (fifo_r + 1) & 0x0f;
		fifo_count--;
	}
	fifo[fifo_w] = data;
	fifo_w = (fifo_w + 1) & 0x0f;
	fifo_count++;
	keyboard_probe_log("KEY enqueue data=%02X '%c' count=%d", data, (data >= 0x20 && data < 0x7f) ? data : '.', fifo_count);
}

void KEYBOARD::send_ascii(uint8_t data)
{
	// CP/M polls SIO-B RR0 before reading data; keep a small host-side FIFO
	// so status and data stay coherent even without full serial bit timing.
	enqueue(data);
}

void KEYBOARD::key_down(int code, bool repeat)
{
	if(code == VK_CAPITAL) {
		if(!repeat) {
			caps = !caps;
		}
		return;
	}
	if(code == VK_KANA) {
		if(!repeat) {
			kana = !kana;
		}
		return;
	}

	int data = translate_key(code & 0xff);
	if(data >= 0) {
		keyboard_probe_log("KEY down code=%02X translated=%02X repeat=%d", code & 0xff, data & 0xff, repeat ? 1 : 0);
		send_ascii((uint8_t)data);
	} else {
		keyboard_probe_log("KEY down code=%02X ignored repeat=%d", code & 0xff, repeat ? 1 : 0);
	}
}

void KEYBOARD::key_up(int code)
{
	(void)code;
}

bool KEYBOARD::has_data() const
{
	return fifo_count > 0;
}

uint8_t KEYBOARD::read_data()
{
	if(fifo_count <= 0) {
		return 0;
	}
	uint8_t data = fifo[fifo_r];
	fifo_r = (fifo_r + 1) & 0x0f;
	fifo_count--;
	keyboard_probe_log("KEY read data=%02X '%c' count=%d", data, (data >= 0x20 && data < 0x7f) ? data : '.', fifo_count);
	return data;
}

#define STATE_VERSION	2

bool KEYBOARD::process_state(FILEIO* state_fio, bool loading)
{
	if(!state_fio->StateCheckUint32(STATE_VERSION)) {
		return false;
	}
	if(!state_fio->StateCheckInt32(this_device_id)) {
		return false;
	}
	state_fio->StateValue(kana);
	state_fio->StateValue(caps);
	state_fio->StateArray(fifo, sizeof(fifo), 1);
	state_fio->StateValue(fifo_r);
	state_fio->StateValue(fifo_w);
	state_fio->StateValue(fifo_count);
	if(loading) {
		if(fifo_r < 0 || fifo_r >= (int)sizeof(fifo) ||
		   fifo_w < 0 || fifo_w >= (int)sizeof(fifo) ||
		   fifo_count < 0 || fifo_count > (int)sizeof(fifo)) {
			clear_fifo();
		}
	}
	return true;
}
