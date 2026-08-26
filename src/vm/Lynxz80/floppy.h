/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex
	Date   : 2026.05.02-

	[ floppy ]
*/

#ifndef _LYNXZ80_FLOPPY_H_
#define _LYNXZ80_FLOPPY_H_

#include "../vm.h"
#include "../../emu.h"
#include "../device.h"

#define SIG_FLOPPY_PORT_A	0
#define SIG_FLOPPY_PORT_B	1

class FLOPPY : public DEVICE
{
private:
	uint8_t port_a;
	uint8_t port_b;
	uint8_t control_a;
	uint8_t control_b;
	bool head_select_n;
	bool in_use_n;
	bool unsafe_reset_n;
	bool disk2_sense;
	bool romen;
	outputs_t outputs_romen;
	class MB8877* fdc;

	void update_control_latches();

public:
	FLOPPY(VM_TEMPLATE* parent_vm, EMU* parent_emu) : DEVICE(parent_vm, parent_emu)
	{
		set_device_name(_T("Floppy I/F"));
		initialize_output_signals(&outputs_romen);
		port_a = 0;
		port_b = 0;
		control_a = 0;
		control_b = 0;
		head_select_n = true;
		in_use_n = true;
		unsafe_reset_n = true;
		disk2_sense = false;
		romen = false;
		fdc = NULL;
	}
	~FLOPPY() {}

	void reset();
	void write_signal(int id, uint32_t data, uint32_t mask);
	bool process_state(FILEIO* state_fio, bool loading);

	uint8_t get_port_a() const
	{
		return port_a;
	}
	uint8_t get_port_b() const
	{
		return port_b;
	}
	uint8_t get_control_a() const
	{
		return control_a;
	}
	uint8_t get_control_b() const
	{
		return control_b;
	}
	bool get_disk2_sense() const
	{
		return disk2_sense;
	}
	bool get_head_select_n() const
	{
		return head_select_n;
	}
	bool get_in_use_n() const
	{
		return in_use_n;
	}
	bool get_unsafe_reset_n() const
	{
		return unsafe_reset_n;
	}
	bool get_romen() const
	{
		return romen;
	}
	void set_context_fdc(MB8877* device)
	{
		fdc = device;
	}
	void set_context_romen(DEVICE* device, int id, uint32_t mask)
	{
		register_output_signal(&outputs_romen, device, id, mask);
	}
};

#endif
