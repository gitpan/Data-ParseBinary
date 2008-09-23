package Data::ParseBinary::lib::FileSystemMbr;
use strict;
use warnings;
use Data::ParseBinary;
#"""
#Master Boot Record
#The first sector on disk, contains the partition table, bootloader, et al.
#
#http://www.win.tue.nl/~aeb/partitions/partition_types-1.html
#"""

my $mbr = Struct("mbr",
    Bytes("bootloader_code", 446),
    Array(4,
        Struct("partitions",
            Enum(Byte("state"),
                INACTIVE => 0x00,
                ACTIVE => 0x80,
            ),
            BitStruct("beginning",
                Octet("head"),
                BitField("sect", 6),
                BitField("cyl", 10),
            ),
            Enum(UBInt8("type"),
                Nothing => 0x00,
                FAT12 => 0x01,
                XENIX_ROOT => 0x02,
                XENIX_USR => 0x03,
                FAT16_old => 0x04,
                Extended_DOS => 0x05,
                FAT16 => 0x06,
                FAT32 => 0x0b,
                FAT32_LBA => 0x0c,
                NTFS => 0x07,
                LINUX_SWAP => 0x82,
                LINUX_NATIVE => 0x83,
                _default_ => $DefaultPass,
            ),
            BitStruct("ending",
                Octet("head"),
                BitField("sect", 6),
                BitField("cyl", 10),
            ),
            UBInt32("sector_offset"), # offset from MBR in sectors
            UBInt32("size"), # in sectors
        )
    ),
    Const(Bytes("signature", 2), "\x55\xAA"),
);

our $Parser = $mbr;

1;





