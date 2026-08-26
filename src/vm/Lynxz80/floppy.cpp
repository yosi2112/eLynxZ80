/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex
	Date   : 2026.05.02-

	[ floppy ]
*/

#include "floppy.h"
#include "../mb8877.h"
#include "probe_log.h"

#include <stdarg.h>
#include <stdio.h>

#ifdef _DEBUG
static int floppy_probe_log_count = 0;

static void floppy_probe_log(const char* format, ...)
{
	va_list args;
	va_start(args, format);
	probe_log_write("lynxz80_floppy.log", floppy_probe_log_count, format, args);
	va_end(args);
}
#else
static inline void floppy_probe_log(const char* format, ...) { (void)format; }
#endif

#define STATE_VERSION 1

void FLOPPY::update_control_latches()
{
	control_a = port_a & 0x76;
	control_b = port_b & 0x0f;
	head_select_n = ((control_a & 0x02) != 0);
	in_use_n = ((control_a & 0x04) != 0);
	unsafe_reset_n = ((control_a & 0x20) != 0);
	disk2_sense = ((control_a & 0x40) != 0);
	if(fdc != NULL) {
		uint32_t drive = control_b & 0x03;
		bool mfm = ((control_a & 0x10) != 0);
		bool ready = false;

		switch(drive) {
		case 0:
			ready = ((control_b & 0x08) != 0);
			break;
		case 1:
			ready = ((control_b & 0x04) != 0);
			break;
		default:
			ready = false;
			break;
		}
		fdc->write_signal(SIG_MB8877_DRIVEREG, drive, 0x03);
		fdc->write_signal(SIG_MB8877_SIDEREG, disk2_sense ? 1 : 0, 0x01);
		fdc->set_drive_mfm(drive, mfm);
		fdc->write_signal(SIG_MB8877_MOTOR, ready ? 1 : 0, 0x01);
		floppy_probe_log("FLOPPY latch port_a=%02X port_b=%02X control_a=%02X control_b=%02X drive=%u head_select_n=%d in_use_n=%d unsafe_reset_n=%d side=%u density=%s ready=%d motor=%u romen=%d", port_a, port_b, control_a, control_b, drive, head_select_n ? 1 : 0, in_use_n ? 1 : 0, unsafe_reset_n ? 1 : 0, disk2_sense ? 1 : 0, mfm ? "MFM" : "FM", ready ? 1 : 0, fdc->read_signal(SIG_MB8877_MOTOR), romen ? 1 : 0);
	}
}

void FLOPPY::reset()
{
	port_a = 0;
	port_b = 0x80;
	control_a = 0;
	control_b = 0;
	head_select_n = true;
	in_use_n = true;
	unsafe_reset_n = true;
	disk2_sense = false;
	romen = true;
	update_control_latches();
	write_signals(&outputs_romen, 0x80);
}

void FLOPPY::write_signal(int id, uint32_t data, uint32_t mask)
{
	uint8_t value = (uint8_t)(data & mask);

	switch(id) {
	case SIG_FLOPPY_PORT_A:
		// PA0 is MB8877 IRQ input to the PIO. PA3 and PA7 are not connected.
		// PA1, PA2, and PA5 are active-low control outputs; PA4 is density; PA6 selects side.
		port_a = value & 0x76;
		update_control_latches();
		break;

	case SIG_FLOPPY_PORT_B:
		// PB0..PB3 are part of the drive-control truth table.
		// PB7 is ROMEN. PB4..PB6 are not connected.
		port_b = value & 0x8f;
		romen = ((port_b & 0x80) != 0);
		update_control_latches();
		write_signals(&outputs_romen, romen ? 0x80 : 0x00);
		break;
	}
}

bool FLOPPY::process_state(FILEIO* state_fio, bool loading)
{
	if(!state_fio->StateCheckUint32(STATE_VERSION)) {
		return false;
	}
	if(!state_fio->StateCheckInt32(this_device_id)) {
		return false;
	}
	state_fio->StateValue(port_a);
	state_fio->StateValue(port_b);
	state_fio->StateValue(control_a);
	state_fio->StateValue(control_b);
	state_fio->StateValue(disk2_sense);
	state_fio->StateValue(romen);
	if(loading) {
		update_control_latches();
		write_signals(&outputs_romen, romen ? 0x80 : 0x00);
	}
	return true;
}
