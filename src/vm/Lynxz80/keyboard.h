/*
	Lynx Z80 Emulator

	Author : OpenAI Codex
	Date   : 2026.05.08-

	[ keyboard ]
*/

#ifndef _LYNXZ80_KEYBOARD_H_
#define _LYNXZ80_KEYBOARD_H_

#include "../vm.h"
#include "../../emu.h"
#include "../device.h"

class Z80SIO;
class KEYBOARD : public DEVICE
{
private:
	Z80SIO* d_sio;
	const uint8_t* key_stat;
	bool kana;
	bool caps;
	uint8_t fifo[16];
	int fifo_r;
	int fifo_w;
	int fifo_count;

	bool is_shifted() const;
	bool is_controlled() const;
	int translate_key(int code) const;
	void clear_fifo();
	void enqueue(uint8_t data);
	void send_ascii(uint8_t data);

public:
	KEYBOARD(VM_TEMPLATE* parent_vm, EMU* parent_emu) : DEVICE(parent_vm, parent_emu)
	{
		d_sio = NULL;
		key_stat = NULL;
		kana = false;
		caps = false;
		clear_fifo();
		set_device_name(_T("Keyboard"));
	}
	~KEYBOARD() {}

	void initialize();
	void reset();
	bool process_state(FILEIO* state_fio, bool loading);

	void set_context_sio(Z80SIO* device)
	{
		d_sio = device;
	}
	void key_down(int code, bool repeat);
	void key_up(int code);
	bool has_data() const;
	uint8_t read_data();
	bool get_caps_locked()
	{
		return caps;
	}
	bool get_kana_locked()
	{
		return kana;
	}
};

#endif
