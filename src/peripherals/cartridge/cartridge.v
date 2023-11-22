module cartridge

import peripherals.cartridge.mbc { Mbc }

pub struct Cartridge {
	rom     []u8
	savable bool
mut:
	ram []u8
	mbc mbc.Mbc
pub:
	cgb_flag bool
}

pub fn Cartridge.new(rom []u8) Cartridge {
	header := unsafe { *(&CartridgeHeader(&rom[0x100])) }
	header.check_sum()

	title := unsafe { tos_clone(&header.title[0]) }
	rom_size := header.rom_size()
	sram_size := header.sram_size()
	rom_banks := rom_size >> 14
	m := Mbc.new(header.cartridge_type, rom_banks)

	println('cartridge info { title: ${title}, type: ${m}, rom_size: ${rom_size} B, sram_size: ${sram_size} B }')
	assert rom.len == rom_size, 'expected ${rom_size} bytes of cartridge ROM, got ${rom.len}'

	return Cartridge{
		rom: rom
		ram: []u8{len: sram_size}
		mbc: m
		savable: header.is_savable()
		cgb_flag: true // header.cgb_flag & 0x80 > 0
	}
}

pub fn (c &Cartridge) read(addr u16) u8 {
	return match addr {
		0x0000...0x7FFF {
			c.rom[c.mbc.get_addr(addr) & (c.rom.len - 1)]
		}
		0xA000...0xBFFF {
			if c.mbc.sram_enable() {
				c.ram[c.mbc.get_addr(addr) & (c.ram.len - 1)]
			} else {
				0xFF
			}
		}
		else {
			panic('unexpected address for cartridge: ${addr}')
		}
	}
}

pub fn (mut c Cartridge) write(addr u16, val u8) {
	match addr {
		0x0000...0x7FFF {
			c.mbc.write(addr, val)
		}
		0xA000...0xBFFF {
			if c.mbc.sram_enable() {
				c.ram[c.mbc.get_addr(addr) & (c.ram.len - 1)] = val
			}
		}
		else {
			panic('unexpected address for cartridge: ${addr}')
		}
	}
}

pub fn (c &Cartridge) save() []u8 {
	return c.ram.clone()
}

pub fn (mut c Cartridge) load(data []u8) {
	assert data.len == c.ram.len, 'expected ${c.ram.len} bytes of save data, got ${data.len}'
	c.ram = data
}

pub fn (c &Cartridge) is_savable() bool {
	return c.savable
}
