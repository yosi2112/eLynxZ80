/*
	Lynx Z80 Emulator

	Author : OpenAI Codex
	Date   : 2026.05.01-

	[ virtual machine ]
*/

#include "LynxZ80.h"
#include "../../emu.h"
#include "../device.h"
#include "../disk.h"
#include "../event.h"
#include "../memory.h"
#include "../mb8877.h"
#include "../noise.h"
#include "../upd7220.h"
#include "../z80.h"
#include "../z80ctc.h"
#include "../z80dma.h"
#include "../z80pio.h"
#include "../z80sio.h"
#ifdef USE_DEBUGGER
#include "../debugger.h"
#endif

#include "floppy.h"
#include "display.h"
#include "keyboard.h"
#include "serial.h"
#include "Membus.h"
#include "probe_log.h"

#include <stdarg.h>
#include <stdio.h>

namespace {
static int probe_log_count = 0;
static int bridge_log_count = 0;
static int gdc_txt_log_count = 0;
static int gdc_grph_log_count = 0;
static uint8_t probe_last_main_status = 0xff;
static bool probe_last_main_status_valid = false;
static uint8_t probe_last_fdc_status = 0xff;
static bool probe_last_fdc_status_valid = false;
static int probe_fdc_status_repeat = 0;
static int probe_fdc_data_read_count = 0;
static int probe_sub_empty_count = 0;
static int probe_sub_busy_write_count = 0;

#ifdef _DEBUG
static void probe_log(const char* format, ...)
{
	if(probe_log_count >= 200000) {
		return;
	}
	va_list args;
	va_start(args, format);
	probe_log_write("lynxz80_main.log", probe_log_count, format, args);
	va_end(args);
}

static void bridge_log(const char* format, ...)
{
	va_list args;
	va_start(args, format);
	probe_log_write("lynxz80_bridge.log", bridge_log_count, format, args);
	va_end(args);
}

static void gdc_txt_log(const char* format, ...)
{
	if(gdc_txt_log_count >= 2048 && (gdc_txt_log_count & 0xfff) != 0) {
		gdc_txt_log_count++;
		return;
	}
	va_list args;
	va_start(args, format);
	probe_log_write("lynxz80_gdc_txt.log", gdc_txt_log_count, format, args);
	va_end(args);
}

static void gdc_grph_log(const char* format, ...)
{
	if(gdc_grph_log_count >= 2048 && (gdc_grph_log_count & 0xfff) != 0) {
		gdc_grph_log_count++;
		return;
	}
	va_list args;
	va_start(args, format);
	probe_log_write("lynxz80_gdc_grph.log", gdc_grph_log_count, format, args);
	va_end(args);
}
#endif

static bool load_local_binary(const _TCHAR* path, uint8_t* buffer, size_t size)
{
	FILEIO fio;
	if(!fio.Fopen(create_local_path(path), FILEIO_READ_BINARY)) {
		return false;
	}
	fio.Fread(buffer, (int)size, 1);
	fio.Fclose();
	return true;
}

constexpr uint32_t kUnmappedIoValue = 0xff;

enum MainIoGroup : uint32_t {
	kGroupSio = 0,
	kGroupCtc = 1,
	kGroupDma = 2,
	kGroupFdc = 3,
	kGroupPio = 4,
	kGroupSub = 7,
};

inline bool io_decoder_enabled(uint32_t addr)
{
	return ((addr & 0xe0) == 0x20);
}

inline bool main_minsub_selected(uint32_t addr)
{
	return ((addr & 0xfc) == 0x3c);
}

inline uint32_t io_group(uint32_t addr)
{
	return (addr >> 2) & 0x07;
}

inline uint32_t io_reg(uint32_t addr)
{
	return addr & 0x03;
}

inline uint32_t sio_reg(uint32_t addr)
{
	uint32_t reg = io_reg(addr);
	return ((reg & 0x01) << 1) | ((reg & 0x02) >> 1);
}

inline uint32_t pio_reg(uint32_t addr)
{
	uint32_t reg = io_reg(addr);
	return ((reg & 0x01) << 1) | ((reg & 0x02) >> 1);
}

inline bool sub_cgdc_selected(uint32_t addr)
{
	return ((addr & 0x82) == 0x00);
}

inline bool sub_ggdc_selected(uint32_t addr)
{
	return ((addr & 0x82) == 0x02);
}

inline bool sub_minsub_selected(uint32_t addr)
{
	return ((addr & 0x82) == 0x80);
}
}

#define SIG_MAINIO_SUB_SEL	0

class MAINIO : public DEVICE
{
private:
	MainSubBridge* bridge;
	Z80DMA* dma;
	Z80PIO* pio;
	Z80SIO* sio;
	Z80CTC* ctc;
	MB8877* fdc;
	KEYBOARD* keyboard;
	bool sub_selected;

public:
	MAINIO(VM_TEMPLATE* parent_vm, EMU* parent_emu) : DEVICE(parent_vm, parent_emu)
	{
		set_device_name(_T("Main I/O Bus"));
		bridge = NULL;
		dma = NULL;
		pio = NULL;
		sio = NULL;
		ctc = NULL;
		fdc = NULL;
		keyboard = NULL;
		sub_selected = false;
	}

	void reset();
	void write_io8(uint32_t addr, uint32_t data);
	uint32_t read_io8(uint32_t addr);
	void write_signal(int id, uint32_t data, uint32_t mask);

	void set_context_bridge(MainSubBridge* device)
	{
		bridge = device;
	}
	void set_context_dma(Z80DMA* device)
	{
		dma = device;
	}
	void set_context_pio(Z80PIO* device)
	{
		pio = device;
	}
	void set_context_sio(Z80SIO* device)
	{
		sio = device;
	}
	void set_context_ctc(Z80CTC* device)
	{
		ctc = device;
	}
	void set_context_fdc(MB8877* device)
	{
		fdc = device;
#ifdef _DEBUG
		probe_log("MAINIO set_context_fdc ptr=%p", device);
#endif
	}
	void set_context_keyboard(KEYBOARD* device)
	{
		keyboard = device;
	}
};

class SUBIO : public DEVICE
{
private:
	MainSubBridge* bridge;
	UPD7220* cgdc;
	UPD7220* ggdc;

public:
	SUBIO(VM_TEMPLATE* parent_vm, EMU* parent_emu) : DEVICE(parent_vm, parent_emu)
	{
		set_device_name(_T("Sub I/O Bus"));
		bridge = NULL;
		cgdc = NULL;
		ggdc = NULL;
	}

	void write_io8(uint32_t addr, uint32_t data);
	uint32_t read_io8(uint32_t addr);

	void set_context_bridge(MainSubBridge* device)
	{
		bridge = device;
	}
	void set_context_cgdc(UPD7220* device)
	{
		cgdc = device;
	}
	void set_context_ggdc(UPD7220* device)
	{
		ggdc = device;
	}
};

MainSubBridge::MainSubBridge()
{
	reset();
}

void MainSubBridge::reset()
{
	main_to_sub_data_ = 0;
	dr_full_ = false;
	sub_busy_ = true;
#ifdef _DEBUG
	probe_log("BRIDGE reset");
#endif
}

uint8_t MainSubBridge::main_io_read(uint8_t addr) const
{
	uint8_t value = is_minsub_addr(addr) ? build_status() : 0xff;
	if(is_minsub_addr(addr) && (!probe_last_main_status_valid || probe_last_main_status != value)) {
#ifdef _DEBUG
		bridge_log("MINSUB main read addr=%02X status=%02X dr=%d busy=%d", addr, value, dr_full_ ? 1 : 0, sub_busy_ ? 1 : 0);
#endif
		probe_last_main_status = value;
		probe_last_main_status_valid = true;
	}
	return value;
}

void MainSubBridge::main_io_write(uint8_t addr, uint8_t data)
{
	if(!is_minsub_addr(addr)) {
		return;
	}
	main_to_sub_data_ = data;
	dr_full_ = true;
#ifdef LYNXZ80_CLI_CONSOLE
	putchar(data);
	fflush(stdout);
#endif
#ifdef _DEBUG
	bridge_log("MINSUB main write addr=%02X data=%02X '%c'", addr, data, (data >= 0x20 && data < 0x7f) ? data : '.');
#endif
}

uint8_t MainSubBridge::sub_io_read(uint8_t addr)
{
	if(!is_minsub_addr(addr)) {
		return 0xff;
	}
	if(!dr_full_) {
		if((probe_sub_empty_count++ & 0xff) == 0) {
#ifdef _DEBUG
			bridge_log("MINSUB sub read addr=%02X empty", addr);
#endif
		}
		return 0x00;
	}
	dr_full_ = false;
	probe_sub_empty_count = 0;
#ifdef _DEBUG
	bridge_log("MINSUB sub read addr=%02X data=%02X '%c'", addr, main_to_sub_data_, (main_to_sub_data_ >= 0x20 && main_to_sub_data_ < 0x7f) ? main_to_sub_data_ : '.');
#endif
	return main_to_sub_data_;
}

void MainSubBridge::sub_io_write(uint8_t addr, uint8_t data)
{
	if(!is_minsub_addr(addr)) {
		return;
	}
	sub_busy_ = ((data & kStatusSubBusy) != 0);
#ifdef _DEBUG
	if((data & ~kStatusSubBusy) != 0 || ((probe_sub_busy_write_count++ & 0x3ff) == 0)) {
		bridge_log("MINSUB sub write addr=%02X data=%02X busy=%d", addr, data, sub_busy_ ? 1 : 0);
	}
#endif
}

bool MainSubBridge::dr_full() const
{
	return dr_full_;
}

bool MainSubBridge::sub_busy() const
{
	return sub_busy_;
}

uint8_t MainSubBridge::main_to_sub_data() const
{
	return main_to_sub_data_;
}

void MainSubBridge::set_state(uint8_t data, bool dr_full, bool sub_busy)
{
	main_to_sub_data_ = data;
	dr_full_ = dr_full;
	sub_busy_ = sub_busy;
}

bool MainSubBridge::is_minsub_addr(uint8_t addr) const
{
	return ((addr & 0xfc) == 0x3c) || ((addr & 0x82) == kPortMinSub);
}

uint8_t MainSubBridge::build_status() const
{
	return (dr_full_ ? kStatusDrFull : 0x00) |
	       (sub_busy_ ? kStatusSubBusy : 0x00);
}

void MAINIO::reset()
{
	sub_selected = false;
}

void MAINIO::write_io8(uint32_t addr, uint32_t data)
{
	if(bridge != NULL && main_minsub_selected(addr)) {
		bridge->main_io_write(static_cast<uint8_t>(addr), static_cast<uint8_t>(data));
		return;
	}
	if(!io_decoder_enabled(addr)) {
		return;
	}
	if(sio != NULL && io_group(addr) == kGroupSio) {
		sio->write_io8(sio_reg(addr), data);
		return;
	}
	if(ctc != NULL && io_group(addr) == kGroupCtc) {
		ctc->write_io8(io_reg(addr), data);
		return;
	}
	if(dma != NULL && io_group(addr) == kGroupDma) {
		dma->write_io8(0, data);
		return;
	}
	if(pio != NULL && io_group(addr) == kGroupPio) {
#ifdef _DEBUG
		probe_log("PIO write port=%02X reg=%u pio_reg=%u data=%02X", (uint8_t)addr, io_reg(addr), pio_reg(addr), (uint8_t)data);
#endif
		pio->write_io8(pio_reg(addr), data);
		return;
	}
	if(fdc != NULL && io_group(addr) == kGroupFdc) {
#ifdef _DEBUG
		probe_log("FDC write port=%02X reg=%u data=%02X", (uint8_t)addr, io_reg(addr), (uint8_t)data);
#endif
		if(io_reg(addr) == 0) {
			probe_fdc_status_repeat = 0;
			probe_fdc_data_read_count = 0;
		}
		fdc->write_io8(io_reg(addr), data);
		return;
	}
	if(io_group(addr) == kGroupFdc) {
#ifdef _DEBUG
		probe_log("FDC write dropped port=%02X data=%02X fdc=NULL", (uint8_t)addr, (uint8_t)data);
#endif
	}
}

uint32_t MAINIO::read_io8(uint32_t addr)
{
	if(bridge != NULL && main_minsub_selected(addr)) {
		return bridge->main_io_read(static_cast<uint8_t>(addr));
	}
	if(!io_decoder_enabled(addr)) {
		return kUnmappedIoValue;
	}
	if(sio != NULL && io_group(addr) == kGroupSio) {
		uint32_t reg = sio_reg(addr);
		if(keyboard != NULL) {
			if(reg == 2) {
				if(keyboard->has_data()) {
					uint32_t value = keyboard->read_data();
#ifdef _DEBUG
					probe_log("SIOB data read port=%02X data=%02X", (uint8_t)addr, (uint8_t)value);
#endif
					return value;
				}
			}
			if(reg == 3) {
				uint32_t value = sio->read_io8(reg);
				if(keyboard->has_data()) {
					value |= 0x01;
#ifdef _DEBUG
					probe_log("SIOB status read port=%02X data=%02X keyboard_ready=1", (uint8_t)addr, (uint8_t)value);
#endif
					return value;
				}
			}
		}
		return sio->read_io8(reg);
	}
	if(ctc != NULL && io_group(addr) == kGroupCtc) {
		return ctc->read_io8(io_reg(addr));
	}
	if(dma != NULL && io_group(addr) == kGroupDma) {
		return dma->read_io8(0);
	}
	if(pio != NULL && io_group(addr) == kGroupPio) {
		return pio->read_io8(pio_reg(addr));
	}
	if(fdc != NULL && io_group(addr) == kGroupFdc) {
		uint32_t value = fdc->read_io8(io_reg(addr));
		if(io_reg(addr) == 0) {
			bool notable = (value == 0) || ((value & 0x98) != 0);
			if(!probe_last_fdc_status_valid || notable || ((++probe_fdc_status_repeat & 0x3ff) == 0)) {
#ifdef _DEBUG
				probe_log("FDC read port=%02X reg=%u data=%02X", (uint8_t)addr, io_reg(addr), (uint8_t)value);
#endif
				probe_last_fdc_status = (uint8_t)value;
				probe_last_fdc_status_valid = true;
			}
		} else {
			if(io_reg(addr) == 3) {
				if(probe_fdc_data_read_count < 8 || ((probe_fdc_data_read_count & 0x7f) == 0x7f)) {
#ifdef _DEBUG
					probe_log("FDC read port=%02X reg=%u index=%d data=%02X", (uint8_t)addr, io_reg(addr), probe_fdc_data_read_count, (uint8_t)value);
#endif
				}
				probe_fdc_data_read_count++;
			} else {
#ifdef _DEBUG
				probe_log("FDC read port=%02X reg=%u data=%02X", (uint8_t)addr, io_reg(addr), (uint8_t)value);
#endif
			}
		}
		return value;
	}
	if(io_group(addr) == kGroupFdc) {
#ifdef _DEBUG
		probe_log("FDC read unmapped port=%02X fdc=NULL", (uint8_t)addr);
#endif
	}
	return kUnmappedIoValue;
}

void MAINIO::write_signal(int id, uint32_t data, uint32_t mask)
{
	if(id == SIG_MAINIO_SUB_SEL) {
		sub_selected = ((data & mask) != 0);
	}
}

void SUBIO::write_io8(uint32_t addr, uint32_t data)
{
	if(cgdc != NULL && sub_cgdc_selected(addr)) {
		cgdc->write_io8(addr & 0x01, data);
#ifdef _DEBUG
		gdc_txt_log("SUB GDC TXT write port=%02X reg=%u data=%02X", addr, addr & 0x01, data);
#endif
		return;
	}
	if(ggdc != NULL && sub_ggdc_selected(addr)) {
		ggdc->write_io8(addr & 0x01, data);
#ifdef _DEBUG
		gdc_grph_log("SUB GDC GRPH write port=%02X reg=%u data=%02X", addr, addr & 0x01, data);
#endif
		return;
	}
	if(bridge != NULL && sub_minsub_selected(addr)) {
		bridge->sub_io_write(static_cast<uint8_t>(addr), static_cast<uint8_t>(data));
	}
}

uint32_t SUBIO::read_io8(uint32_t addr)
{
	if(cgdc != NULL && sub_cgdc_selected(addr)) {
		uint32_t value = cgdc->read_io8(addr & 0x01);
#ifdef _DEBUG
		gdc_txt_log("SUB GDC TXT read port=%02X reg=%u data=%02X", addr, addr & 0x01, (uint8_t)value);
#endif
		return value;
	}
	if(ggdc != NULL && sub_ggdc_selected(addr)) {
		uint32_t value = ggdc->read_io8(addr & 0x01);
#ifdef _DEBUG
		gdc_grph_log("SUB GDC GRPH read port=%02X reg=%u data=%02X", addr, addr & 0x01, (uint8_t)value);
#endif
		return value;
	}
	if(bridge != NULL && sub_minsub_selected(addr)) {
		return bridge->sub_io_read(static_cast<uint8_t>(addr));
	}
	return kUnmappedIoValue;
}

VM::VM(EMU* parent_emu) : VM_TEMPLATE(parent_emu)
{
	first_device = last_device = NULL;
	dummy = new DEVICE(this, emu);
	event = new EVENT(this, emu);
	memory = new MEMBUS(this, emu);
	memory_sub = new MEMORY(this, emu);
	cpu_main = new Z80(this, emu);
	cpu_sub = new Z80(this, emu);
#ifdef USE_DEBUGGER
	debugger_main = new DEBUGGER(this, emu);
	debugger_sub = new DEBUGGER(this, emu);
#endif
	dma = new Z80DMA(this, emu);
	pio = new Z80PIO(this, emu);
	sio = new Z80SIO(this, emu);
	ctc = new Z80CTC(this, emu);
	cgdc = new UPD7220(this, emu);
	ggdc = new UPD7220(this, emu);
	fdc = new MB8877(this, emu);
	fdc->set_context_noise_seek(new NOISE(this, emu));
	fdc->set_context_noise_head_down(new NOISE(this, emu));
	fdc->set_context_noise_head_up(new NOISE(this, emu));
	floppy = new FLOPPY(this, emu);
	display = new DISPLAY(this, emu);
	keyboard = new KEYBOARD(this, emu);
	serial = new SERIAL(this, emu);
	
	mainio = new MAINIO(this, emu);
	subio = new SUBIO(this, emu);
	
	mainio->set_context_bridge(&main_sub_bridge);
	mainio->set_context_dma(dma);
	mainio->set_context_pio(pio);
	mainio->set_context_sio(sio);
	mainio->set_context_ctc(ctc);
	mainio->set_context_fdc(fdc);
	mainio->set_context_keyboard(keyboard);
	subio->set_context_bridge(&main_sub_bridge);
	subio->set_context_cgdc(cgdc);
	subio->set_context_ggdc(ggdc);
	floppy->set_context_fdc(fdc);
	floppy->set_context_romen(memory, SIG_MEMBUS_ROMEN, 0x80);
	keyboard->set_context_sio(sio);
	serial->set_context_sio(sio);
	
	event->set_context_cpu(cpu_main);
	event->set_context_cpu(cpu_sub);
	event->set_context_sound(fdc->get_context_noise_seek());
	event->set_context_sound(fdc->get_context_noise_head_down());
	event->set_context_sound(fdc->get_context_noise_head_up());
	
	cpu_main->set_device_name(_T("Z80 CPU (Main)"));
	cpu_sub->set_device_name(_T("Z80 CPU (Sub)"));
	
	cpu_main->set_context_mem(memory);
	cpu_main->set_context_io(mainio);
	cpu_main->set_context_intr(ctc);
#ifdef USE_DEBUGGER
	cpu_main->set_context_debugger(debugger_main);
#endif
	
	memset(sub_rom, 0xff, sizeof(sub_rom));
	memset(sub_ram, 0x00, sizeof(sub_ram));
	sub_rom[0] = 0xc3;
	sub_rom[1] = 0x00;
	sub_rom[2] = 0x00;
	memset(&sub_rom[3], 0x76, sizeof(sub_rom) - 3);
	memory_sub->set_memory_r(0x0000, 0x1fff, sub_rom);
	memory_sub->set_memory_rw(0x8000, 0x87ff, sub_ram);
	cgdc->set_device_name(_T("uPD7220 GDC (Character)"));
	ggdc->set_device_name(_T("uPD7220 GDC (Graphics)"));
	cgdc->set_vram_ptr(display->get_tvram(), 0x1000);
	cgdc->set_context_vsync(cpu_sub, SIG_CPU_IRQ, 1);
	ggdc->set_vram_ptr(display->get_gvram(), display->get_gvram_size());
	ggdc->set_plane_size(0x10000);
	display->set_context_gdc_chr(cgdc, cgdc->get_sync(), cgdc->get_ra(), cgdc->get_cs());
	display->set_context_gdc_gfx(ggdc, ggdc->get_sync(), ggdc->get_ra(), ggdc->get_cs());
	
	cpu_sub->set_context_mem(memory_sub);
	cpu_sub->set_context_io(subio);
	cpu_sub->set_context_intr(dummy);
#ifdef USE_DEBUGGER
	cpu_sub->set_context_debugger(debugger_sub);
#endif
	
	dma->set_context_memory(memory);
	dma->set_context_io(mainio);
	fdc->set_context_irq(cpu_main, SIG_CPU_IRQ, 1);
	fdc->set_context_irq(pio, SIG_Z80PIO_PORT_A, 0x01);
	fdc->set_context_drq(dma, SIG_Z80DMA_READY, 1);
	
	ctc->set_context_intr(cpu_main, 0);
	ctc->set_context_child(sio);
	sio->set_context_intr(cpu_main, 1);
	sio->set_context_child(pio);
	pio->set_context_intr(cpu_main, 2);
	pio->set_context_child(dma);
	dma->set_context_intr(cpu_main, 3);
	pio->set_context_port_a(floppy, SIG_FLOPPY_PORT_A, 0xff, 0);
	pio->set_context_port_b(floppy, SIG_FLOPPY_PORT_B, 0xff, 0);
	load_local_binary(_T("SUBCPU.ROM"), sub_rom, sizeof(sub_rom));
	
	for(DEVICE* device = first_device; device; device = device->next_device) {
		device->initialize();
	}
	for(int drv = 0; drv < MAX_DRIVE; drv++) {
		fdc->set_drive_type(drv, DRIVE_TYPE_2D);
		fdc->set_drive_rpm(drv, 300);
		fdc->set_drive_mfm(drv, false);
	}
}

VM::~VM()
{
	for(DEVICE* device = first_device; device;) {
		DEVICE* next_device = device->next_device;
		device->release();
		delete device;
		device = next_device;
	}
}

DEVICE* VM::get_device(int id)
{
	for(DEVICE* device = first_device; device; device = device->next_device) {
		if(device->this_device_id == id) {
			return device;
		}
	}
	return NULL;
}

void VM::reset()
{
	main_sub_bridge.reset();
	for(DEVICE* device = first_device; device; device = device->next_device) {
		device->reset();
	}
}

void VM::run()
{
	event->drive();
}

void VM::update_config()
{
	for(DEVICE* device = first_device; device; device = device->next_device) {
		device->update_config();
	}
}

void VM::initialize_sound(int rate, int samples)
{
	event->initialize_sound(rate, samples);
}

uint16_t* VM::create_sound(int* extra_frames)
{
	return event->create_sound(extra_frames);
}

#ifdef USE_SOUND_VOLUME
void VM::set_sound_device_volume(int ch, int decibel_l, int decibel_r)
{
	if(ch == 0 && fdc != NULL) {
		fdc->get_context_noise_seek()->set_volume(0, decibel_l, decibel_r);
		fdc->get_context_noise_head_down()->set_volume(0, decibel_l, decibel_r);
		fdc->get_context_noise_head_up()->set_volume(0, decibel_l, decibel_r);
	}
}
#endif

#ifdef USE_DEBUGGER
DEVICE* VM::get_cpu(int index)
{
	if(index == 0) {
		return cpu_main;
	}
	if(index == 1) {
		return cpu_sub;
	}
	return NULL;
}
#endif

void VM::draw_screen()
{
	display->draw_screen();
}

void VM::key_down(int code, bool repeat)
{
	if(keyboard != NULL) {
		keyboard->key_down(code, repeat);
	}
}

void VM::key_up(int code)
{
	if(keyboard != NULL) {
		keyboard->key_up(code);
	}
}

bool VM::get_caps_locked()
{
	return keyboard != NULL ? keyboard->get_caps_locked() : false;
}

bool VM::get_kana_locked()
{
	return keyboard != NULL ? keyboard->get_kana_locked() : false;
}

#ifdef USE_SOCKET
void VM::notify_socket_connected(int ch)
{
	if(serial != NULL) {
		serial->notify_socket_connected(ch);
	}
}

void VM::notify_socket_disconnected(int ch)
{
	if(serial != NULL) {
		serial->notify_socket_disconnected(ch);
	}
}

uint8_t* VM::get_socket_send_buffer(int ch, int* size)
{
	if(serial != NULL) {
		return serial->get_socket_send_buffer(ch, size);
	}
	if(size != NULL) {
		*size = 0;
	}
	return NULL;
}

void VM::inc_socket_send_buffer_ptr(int ch, int size)
{
	if(serial != NULL) {
		serial->inc_socket_send_buffer_ptr(ch, size);
	}
}

uint8_t* VM::get_socket_recv_buffer0(int ch, int* size0, int* size1)
{
	if(serial != NULL) {
		return serial->get_socket_recv_buffer0(ch, size0, size1);
	}
	if(size0 != NULL) {
		*size0 = 0;
	}
	if(size1 != NULL) {
		*size1 = 0;
	}
	return NULL;
}

uint8_t* VM::get_socket_recv_buffer1(int ch)
{
	return serial != NULL ? serial->get_socket_recv_buffer1(ch) : NULL;
}

void VM::inc_socket_recv_buffer_ptr(int ch, int size)
{
	if(serial != NULL) {
		serial->inc_socket_recv_buffer_ptr(ch, size);
	}
}
#endif

bool VM::process_state(FILEIO* state_fio, bool loading)
{
#define STATE_VERSION 4
	if(!state_fio->StateCheckUint32(STATE_VERSION)) {
		return false;
	}
	for(DEVICE* device = first_device; device; device = device->next_device) {
		const _TCHAR* name = char_to_tchar(typeid(*device).name() + 6);
		int len = (int)_tcslen(name);

		if(!state_fio->StateCheckInt32(len)) {
			return false;
		}
		if(!state_fio->StateCheckBuffer(name, len, 1)) {
			return false;
		}
		if(!device->process_state(state_fio, loading)) {
			return false;
		}
	}
	state_fio->StateArray(sub_rom, sizeof(sub_rom), 1);
	state_fio->StateArray(sub_ram, sizeof(sub_ram), 1);

	uint8_t bridge_data = main_sub_bridge.main_to_sub_data();
	bool bridge_dr_full = main_sub_bridge.dr_full();
	bool bridge_sub_busy = main_sub_bridge.sub_busy();
	state_fio->StateValue(bridge_data);
	state_fio->StateValue(bridge_dr_full);
	state_fio->StateValue(bridge_sub_busy);
	if(loading) {
		main_sub_bridge.set_state(bridge_data, bridge_dr_full, bridge_sub_busy);
	}
	return true;
}

void VM::open_floppy_disk(int drv, const _TCHAR *file_path, int bank)
{
	if(fdc != NULL && drv >= 0 && drv < MAX_DRIVE) {
		fdc->open_disk(drv, file_path, bank);
#ifdef _DEBUG
		probe_log("FDD open drive=%d inserted=%d path=%s", drv, fdc->is_disk_inserted(drv) ? 1 : 0, file_path);
#endif
	}
}

void VM::close_floppy_disk(int drv)
{
	if(fdc != NULL && drv >= 0 && drv < MAX_DRIVE) {
		fdc->close_disk(drv);
#ifdef _DEBUG
		probe_log("FDD close drive=%d inserted=%d", drv, fdc->is_disk_inserted(drv) ? 1 : 0);
#endif
	}
}

bool VM::is_floppy_disk_inserted(int drv)
{
	if(fdc != NULL && drv >= 0 && drv < MAX_DRIVE) {
		return fdc->is_disk_inserted(drv);
	}
	return false;
}

void VM::is_floppy_disk_protected(int drv, bool value)
{
	if(fdc != NULL && drv >= 0 && drv < MAX_DRIVE) {
		fdc->is_disk_protected(drv, value);
	}
}

bool VM::is_floppy_disk_protected(int drv)
{
	if(fdc != NULL && drv >= 0 && drv < MAX_DRIVE) {
		return fdc->is_disk_protected(drv);
	}
	return false;
}

uint32_t VM::is_floppy_disk_accessed()
{
	return fdc != NULL ? fdc->read_signal(SIG_MB8877_ACCESS) : 0;
}

bool VM::is_frame_skippable()
{
	return event->is_frame_skippable();
}
