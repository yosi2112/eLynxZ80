/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex

	[ keyboard ]
*/

// AKB-3320 Japanese keycap compatible input mapping

#include "keyboard.h"
#include "probe_log.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#ifndef ALPS_KANA_OUTPUT_8BIT
#define ALPS_KANA_OUTPUT_8BIT 1
#endif

enum {
	KEY_ALPS_EISU      = 0xf0,
	KEY_ALPS_KANA      = 0xf1,
	KEY_ALPS_LINE_FEED = 0xf2,

	KEY_ALPS_CAN       = 0xf3,
	KEY_ALPS_ACK       = 0xf4,
	KEY_ALPS_FS        = 0xf5,
	KEY_ALPS_US        = 0xf6,
	KEY_ALPS_DEL       = 0xf7,

	KEY_ALPS_S1        = 0xf8,
	KEY_ALPS_S2        = 0xf9,
	KEY_ALPS_S3        = 0xfa,
	KEY_ALPS_S4        = 0xfb,
	KEY_ALPS_S5        = 0xfc
};

namespace {
static bool pressed(const uint8_t* key_stat, int code)
{
	return key_stat != NULL && key_stat[code & 0xff] != 0;
}

static uint8_t kana_code(uint8_t jisx0201_kana)
{
#if ALPS_KANA_OUTPUT_8BIT
	return jisx0201_kana;
#else
	return (uint8_t)(jisx0201_kana & 0x7f);
#endif
}

static uint8_t alps3320_kana_from_vk(int code, bool shift)
{
	code &= 0xff;

	switch(code) {
	case 0x31: return kana_code(0xc7);                   // 1: nu
	case 0x32: return kana_code(0xcc);                   // 2: fu
	case 0x33: return kana_code(shift ? 0xa7 : 0xb1);    // 3: a / small a
	case 0x34: return kana_code(shift ? 0xa9 : 0xb3);    // 4: u / small u
	case 0x35: return kana_code(shift ? 0xaa : 0xb4);    // 5: e / small e
	case 0x36: return kana_code(shift ? 0xab : 0xb5);    // 6: o / small o
	case 0x37: return kana_code(shift ? 0xac : 0xd4);    // 7: ya / small ya
	case 0x38: return kana_code(shift ? 0xad : 0xd5);    // 8: yu / small yu
	case 0x39: return kana_code(shift ? 0xae : 0xd6);    // 9: yo / small yo
	case 0x30: return kana_code(shift ? 0xa6 : 0xdc);    // 0: wa / wo

	case 0xbd: return kana_code(0xce);                   // -: ho
	case 0xde: return kana_code(0xcd);                   // ^: he
	case 0xdc: return kana_code(0xb0);                   // yen: prolonged sound mark

	case 0x51: return kana_code(0xc0);                   // Q: ta
	case 0x57: return kana_code(0xc3);                   // W: te
	case 0x45: return kana_code(0xb2);                   // E: i
	case 0x52: return kana_code(0xbd);                   // R: su
	case 0x54: return kana_code(0xb6);                   // T: ka
	case 0x59: return kana_code(0xdd);                   // Y: n
	case 0x55: return kana_code(0xc5);                   // U: na
	case 0x49: return kana_code(0xc6);                   // I: ni
	case 0x4f: return kana_code(0xd7);                   // O: ra
	case 0x50: return kana_code(0xbe);                   // P: se
	case 0xc0: return kana_code(0xde);                   // @: voiced mark
	case 0xdb: return kana_code(shift ? 0xa2 : 0xdf);    // [: semi-voiced mark / opening bracket

	case 0x41: return kana_code(0xc1);                   // A: chi
	case 0x53: return kana_code(0xc4);                   // S: to
	case 0x44: return kana_code(0xbc);                   // D: shi
	case 0x46: return kana_code(0xca);                   // F: ha
	case 0x47: return kana_code(0xb7);                   // G: ki
	case 0x48: return kana_code(0xb8);                   // H: ku
	case 0x4a: return kana_code(0xcf);                   // J: ma
	case 0x4b: return kana_code(0xc9);                   // K: no
	case 0x4c: return kana_code(0xd8);                   // L: ri
	case 0xbb: return kana_code(0xda);                   // ;: re
	case 0xba: return kana_code(0xb9);                   // :: ke
	case 0xdd: return kana_code(shift ? 0xa3 : 0xd1);    // ]: mu / closing bracket

	case 0x5a: return kana_code(shift ? 0xaf : 0xc2);    // Z: tsu / small tsu
	case 0x58: return kana_code(0xbb);                   // X: sa
	case 0x43: return kana_code(0xbf);                   // C: so
	case 0x56: return kana_code(0xcb);                   // V: hi
	case 0x42: return kana_code(0xba);                   // B: ko
	case 0x4e: return kana_code(0xd0);                   // N: mi
	case 0x4d: return kana_code(0xd3);                   // M: mo
	case 0xbc: return kana_code(shift ? 0xa4 : 0xc8);    // ,: ne / comma
	case 0xbe: return kana_code(shift ? 0xa1 : 0xd9);    // .: ru / period
	case 0xbf: return kana_code(shift ? 0xa5 : 0xd2);    // /: me / middle dot
	case 0xe2: return kana_code(0xdb);                   // _: ro

	default:
		return 0;
	}
}

static uint8_t alps3320_ascii_from_vk(int code, bool shift, bool caps)
{
	code &= 0xff;

	if(code >= 0x41 && code <= 0x5a) {
		bool upper = caps ^ shift;
		return (uint8_t)(upper ? code : (code + 0x20));
	}

	switch(code) {
	case 0x31: return shift ? '!'  : '1';
	case 0x32: return shift ? '"'  : '2';
	case 0x33: return shift ? '#'  : '3';
	case 0x34: return shift ? '$'  : '4';
	case 0x35: return shift ? '%'  : '5';
	case 0x36: return shift ? '&'  : '6';
	case 0x37: return shift ? '\'' : '7';
	case 0x38: return shift ? '('  : '8';
	case 0x39: return shift ? ')'  : '9';
	case 0x30: return shift ? 0    : '0';

	case 0x20: return ' ';
	case 0x08: return 0x08;
	case 0x09: return 0x09;
	case 0x0d: return 0x0d;
	case 0x1b: return 0x1b;
	case 0x2e: return 0x7f;

	case 0xbd: return shift ? '='  : '-';
	case 0xde: return shift ? '~'  : '^';
	case 0xdc: return shift ? '|'  : '\\';

	case 0xc0: return shift ? '`'  : '@';
	case 0xdb: return shift ? '{'  : '[';
	case 0xdd: return shift ? '}'  : ']';

	case 0xbb: return shift ? '+'  : ';';
	case 0xba: return shift ? '*'  : ':';
	case 0xbc: return shift ? '<'  : ',';
	case 0xbe: return shift ? '>'  : '.';
	case 0xbf: return shift ? '?'  : '/';
	case 0xe2: return shift ? '_'  : '\\';

	default:
		return 0;
	}
}

static uint8_t alps3320_ctrl_from_vk(int code)
{
	code &= 0xff;

	if(code >= 0x41 && code <= 0x5a) {
		return (uint8_t)(code - 0x40);
	}

	switch(code) {
	case 0xc0: return 0x00; // Ctrl-@
	case 0xdb: return 0x1b; // Ctrl-[
	case 0xdc: return 0x1c; // Ctrl-backslash
	case 0xdd: return 0x1d; // Ctrl-]
	case 0xde: return 0x1e; // Ctrl-^
	case 0xe2: return 0x1f; // Ctrl-_
	case 0xbf: return 0x7f; // Ctrl-?
	default:
		return 0;
	}
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
	return pressed(key_stat, 0x10);
}

bool KEYBOARD::is_controlled() const
{
	return pressed(key_stat, 0x11);
}

void KEYBOARD::clear_fifo()
{
	memset(fifo, 0, sizeof(fifo));
	fifo_rpos = 0;
	fifo_wpos = 0;
	fifo_count = 0;
}

void KEYBOARD::key_down(int code, bool repeat)
{
	if(repeat && (code == KEY_ALPS_EISU || code == KEY_ALPS_KANA || code == 0x14 || code == 0x15 || code == 0x1d)) {
		return;
	}
	key_down(code, is_shifted(), is_controlled());
}

void KEYBOARD::key_down(int code, bool shift, bool ctrl)
{
	code &= 0xff;

	if(code == KEY_ALPS_EISU || code == 0x1d) {
		kana = false;
		keyboard_probe_log("KEY eisu code=%02X", code);
		return;
	}

	if(code == KEY_ALPS_KANA || code == 0x15) {
		kana = true;
		keyboard_probe_log("KEY kana code=%02X", code);
		return;
	}

	if(code == 0x14) {
		caps = !caps;
		keyboard_probe_log("KEY caps caps=%d", caps ? 1 : 0);
		return;
	}

	switch(code) {
	case KEY_ALPS_LINE_FEED:
		push_fifo(0x0a);
		return;

	case KEY_ALPS_CAN:
		push_fifo(0x18);
		return;

	case KEY_ALPS_ACK:
		push_fifo(0x06);
		return;

	case KEY_ALPS_FS:
		push_fifo(0x1c);
		return;

	case KEY_ALPS_US:
		push_fifo(0x1f);
		return;

	case KEY_ALPS_DEL:
		push_fifo(0x7f);
		return;

	case KEY_ALPS_S1:
	case KEY_ALPS_S2:
	case KEY_ALPS_S3:
	case KEY_ALPS_S4:
	case KEY_ALPS_S5:
		return;

	default:
		break;
	}

	if(ctrl) {
		uint8_t ch = alps3320_ctrl_from_vk(code);
		if(ch || code == 0xc0) {
			push_fifo(ch);
			return;
		}
	}

	if(kana) {
		uint8_t ch = alps3320_kana_from_vk(code, shift);
		if(ch) {
			push_fifo(ch);
			return;
		}
	}

	uint8_t ch = alps3320_ascii_from_vk(code, shift, caps);
	if(ch) {
		push_fifo(ch);
	}
}

void KEYBOARD::key_up(int code)
{
	(void)code;
}

void KEYBOARD::push_fifo(uint8_t data)
{
	if(fifo_count >= FIFO_SIZE) {
		fifo_rpos = (fifo_rpos + 1) & (FIFO_SIZE - 1);
		fifo_count--;
	}

	fifo[fifo_wpos] = data;
	fifo_wpos = (fifo_wpos + 1) & (FIFO_SIZE - 1);
	fifo_count++;
	keyboard_probe_log("KEY enqueue data=%02X '%c' count=%d", data, (data >= 0x20 && data < 0x7f) ? data : '.', fifo_count);
}

bool KEYBOARD::has_key() const
{
	return fifo_count != 0;
}

uint8_t KEYBOARD::read_key()
{
	if(fifo_count == 0) {
		return 0;
	}

	uint8_t data = fifo[fifo_rpos];
	fifo_rpos = (fifo_rpos + 1) & (FIFO_SIZE - 1);
	fifo_count--;
	keyboard_probe_log("KEY read data=%02X '%c' count=%d", data, (data >= 0x20 && data < 0x7f) ? data : '.', fifo_count);
	return data;
}

bool KEYBOARD::has_data() const
{
	return has_key();
}

uint8_t KEYBOARD::read_data()
{
	return read_key();
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
	state_fio->StateValue(fifo_rpos);
	state_fio->StateValue(fifo_wpos);
	state_fio->StateValue(fifo_count);
	if(loading) {
		if(fifo_rpos < 0 || fifo_rpos >= FIFO_SIZE ||
		   fifo_wpos < 0 || fifo_wpos >= FIFO_SIZE ||
		   fifo_count < 0 || fifo_count > FIFO_SIZE) {
			clear_fifo();
		}
	}
	return true;
}
