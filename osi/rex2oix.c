/* Based bld/w32loadr/w32bind.c in OpenWatcom 1.0 https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip */

#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <io.h>
#include <fcntl.h>
#include <stdarg.h>

#if defined(O_BINARY) && !(O_BINARY)
#  undef O_BINARY
#endif
#ifndef O_BINARY
#  define O_BINARY 0
#endif

#ifdef CONFIG_USE_OPEN2
#  define open(filename, flags) open2(filename, flags)
#endif

void print_str(const char *str) {
  (void)!write(STDOUT_FILENO, str, strlen(str));
}

void print_strs(const char *str, ...) {
  va_list ap;
  va_start(ap, str);
  do {
    print_str(str);
  } while ((str = va_arg(ap, const char *)) != NULL);
}

typedef unsigned short  WORD;
typedef unsigned long   DWORD;

//#include "loader.h"
#pragma pack(1)

typedef struct {
    DWORD off;
    WORD seg;
} addr_48;

typedef struct rex_hdr {
    char    sig[2];
    WORD    file_size1;
    WORD    file_size2;
    WORD    reloc_cnt;
    WORD    file_header;
    WORD    min_data;
    WORD    max_data;
    DWORD   initial_esp;
    WORD    checksum;
    DWORD   initial_eip;
    WORD    first_reloc;
    WORD    overlay_number;
    WORD    one;
} rex_exe;

typedef struct dos_hdr {
    WORD        sig;
    WORD        len_of_load_mod;
    WORD        x;
    WORD        reloc_count;
    WORD        size_of_DOS_header_in_paras;
} dos_hdr;

typedef struct w32_hdr {
    DWORD       sig;
    DWORD       start_of_W32_file;
    DWORD       size_of_W32_file;
    DWORD       offset_to_relocs;
    DWORD       memory_size;
    DWORD       initial_EIP;
} w32_hdr;

#pragma pack()

//---

#define FALSE   0
#define TRUE    1
#define BUFSIZE 4096
#define Align4K( x ) (((x)+0xfffL) & ~0xfffL )

struct padded_hdr {
    rex_exe     hdr;
    WORD        pad;
};

typedef struct {
    DWORD datastart;
    DWORD stackstart;
} exe_data;

DWORD   StackSize;
DWORD   BaseAddr;
unsigned short  *RelocBuffer;

int CmpReloc( const void *_p, const void *_q )
{
    DWORD       reloc1, const *p = _p;
    DWORD       reloc2, const *q = _q;

    reloc1 = *p & 0x7FFFFFFF;
    reloc2 = *q & 0x7FFFFFFF;
    if( reloc1 == reloc2 ) return( 0 ); // shouldn't happen
    if( reloc1 < reloc2 )  return( -1 );
    return( 1 );
}


int CopyRexFile( int handle, int newfile, DWORD filesize )
{
    char        *buf;
    unsigned    amt1;
    unsigned    len;

    buf = malloc( BUFSIZE );
    if( buf == NULL ) {
        print_str( "Out of memory\r\n" );
        return( -1 );
    }
    for(;;) {
        len = filesize;
        if( len > BUFSIZE )  len = BUFSIZE;
        amt1 = read( handle, buf, len );
        if( amt1 != len ) {
            print_str( "Error reading REX file\r\n" );
            free( buf );
            return( -1 );
        }
        if( write( newfile, buf, len ) != len ) {
            print_str( "Error writing file\r\n" );
            free( buf );
            return( -1 );
        }
        filesize -= len;
        if( filesize == 0 ) break;
    }
    free( buf );
    return( 0 );
}

DWORD RelocSize( DWORD *relocs, unsigned n )
{
    DWORD       size;
    DWORD       page;
    unsigned    i;

    i = 0;
    size = 0;
    while( i < n ) {
        size += 2 * sizeof(unsigned short);
        page = relocs[i] & 0x7FFF0000;
        while( i < n ) {
            if( (relocs[i] & 0x7FFF0000) != page ) break;
            i++;
            size += sizeof(unsigned short);
        }
    }
    size += sizeof(unsigned short);
    return( size );
}

int CreateRelocs( DWORD *relocs, unsigned short *newrelocs, unsigned n )
{
    DWORD       page;
    unsigned    i;
    unsigned    j;
    unsigned    k;

    i = 0;
    k = 0;
    while( i < n ) {
        page = relocs[i] & 0x7FFF0000;
        j = i;
        while( j < n ) {
            if( (relocs[j] & 0x7FFF0000) != page ) break;
            j++;
        }
        //printf( "Page: %4.4x  Count: %u\r\n", page >> 16, j - i );
        newrelocs[k++] = j - i;
        newrelocs[k++] = page >> 16;
        newrelocs[k++] = (unsigned short)relocs[i];
        i++;
        for( ; i < j; i++, k++ ) {
            newrelocs[k] = (unsigned short)(relocs[i] - relocs[i-1]);
        }
        i = j;
    }
    newrelocs[k++] = 0;
    return( 0 );
}

static char is_all_zero_bytes(const char *p, DWORD size) {
  for (; size != 0; ++p, --size) {
    if (*p != '\0') return 0;
  }
  return 1;
}

void fix_pmode_w(char *p, DWORD size) {
  dos_hdr *dos_header = (dos_hdr *)p;
  char *h = p + ((DWORD)dos_header->size_of_DOS_header_in_paras << 4);
  if (size >= 10 && dos_header->sig == 'ZM' && size >= (DWORD)(h - p) + 28 && memcmp(h + 21, "PMODE/W", 7) == 0) {
    h[0xe] = 0;  /* Disable displaying the PMODE/W copyright message. */
  }
}

int main( int argc, char *argv[] )
{
    int                 handle;
    int                 loader_handle;
    int                 newfile;
    char                *file;
    DWORD               size;
    DWORD               codesize;
    DWORD               relocsize;
    DWORD               minmem,maxmem;
    DWORD               relsize,exelen;
    DWORD               *relocs;
    DWORD               file_header_size;
    unsigned            len;
    char                *loader_code;
    w32_hdr             *w32_header;
    struct padded_hdr   exehdr;

    if( argc != 3 && argc != 4 ) {
        print_str( "Usage: rex2oix <input.rex> <output.oix> [<mz-stub.exe>]\r\n" );
        exit( 1 );
    }
    argc = 1;
    file = argv[argc];
    ++argc;
    handle = open( file, O_RDONLY | O_BINARY );
    if( handle < 0 ) {
        print_strs("Error opening file '", file, "'\r\n", NULL);
        exit( 1 );
    }

    exelen = 0;
    /*
     * validate header signature
     */
    read( handle, &exehdr, sizeof( rex_exe ) );
    if( !(exehdr.hdr.sig[0] == 'M' && exehdr.hdr.sig[1] == 'Q') ) {
        print_str( "Invalid EXE\r\n" );
        exit( 1 );
    }
    file_header_size = (DWORD) exehdr.hdr.file_header * 16L;
    /*
     * exe.one is supposed to always contain a 1 for a .REX file.
     * However, to allow relocation tables bigger than 64K, the
     * we extended the linker to have the .one field contain the
     * number of full 64K chunks of relocations, minus 1.
     */
    file_header_size += (exehdr.hdr.one-1)*0x10000L*16L;

    /*
     * get file size
     */
    size = (long) exehdr.hdr.file_size2 * 512L;
    if( exehdr.hdr.file_size1 > 0 ) {
        size += (long) exehdr.hdr.file_size1 - 512L;
    }

    /*
     * get minimum/maximum amounts of heap, then add in exe size
     * to get total area
     */
    minmem = (DWORD) exehdr.hdr.min_data *(DWORD) 4096L;
    if( exehdr.hdr.max_data == (unsigned short)-1 ) {
        maxmem = 4096L;
    } else {
        maxmem = (DWORD) exehdr.hdr.max_data*4096L;
    }
    minmem = Align4K( minmem + size );  /* !! Which of these alignments are needed? */
    maxmem = Align4K( maxmem + size );
    if( minmem > maxmem ) {
        maxmem = minmem;
    }
    //printf( "minmem = %lu, maxmem = %lu\r\n", minmem, maxmem );
    //printf( "size = %lu, file_header_size = %lu\r\n", size, file_header_size );
    codesize = size - file_header_size;
    //printf( "code+data size = %lu\r\n", codesize );

    /*
     * get and apply relocation table
     */
    relsize = sizeof( DWORD ) * (DWORD) exehdr.hdr.reloc_cnt;
    {
        DWORD   realsize;
        WORD    kcnt;

        realsize = file_header_size - (DWORD) exehdr.hdr.first_reloc;
        kcnt = realsize / (0x10000L*sizeof(DWORD));
        relsize += kcnt * (0x10000L*sizeof(DWORD));
    }
    //printf( "relocation size = %lu", relsize );
    //printf( " => %lu relocation entries\r\n", relsize / sizeof(DWORD) );
    lseek( handle, exelen + (DWORD) exehdr.hdr.first_reloc, SEEK_SET );
    if( relsize != 0 ) {
        relocs = (DWORD *)malloc( relsize );
        if( relocs == NULL ) {
            print_str( "Out of memory\r\n" );
            return( -1 );
        }
        len = read( handle, relocs, relsize );
        if( len != relsize ) {
            print_str( "Error reading relocation information\r\n" );
            exit( 1 );
        }
        qsort( relocs, relsize / sizeof(DWORD), sizeof(DWORD), CmpReloc );
        if( relocs[0] < 0x80000000 ) {
            print_str( "REX file contains 16-bit relocations\r\n" );
            exit( 1 );
        }
    }
    relocsize = RelocSize( relocs, relsize / sizeof(DWORD) );
    RelocBuffer = (unsigned short *)malloc( relocsize );
    if( RelocBuffer == NULL ) {
        print_str( "Out of memory\r\n" );
        exit( 1 );
    }
    CreateRelocs( relocs, RelocBuffer, relsize / sizeof(DWORD) );

    file = argv[argc++];
    newfile = creat(file, 0666);
    if( newfile < 0 ) {
        print_strs("Error opening file '", file, "'\r\n", NULL);
        exit( 1 );
    }
#if O_BINARY
    setmode(newfile, O_BINARY);
#endif
    file = argv[argc++];
    if (file == NULL) {
        size = 0x18;
        if ((loader_code = calloc(size, 1)) == 0) goto oom;
        w32_header = (w32_hdr *)loader_code;
    } else {
        dos_hdr *dos_header;
        loader_handle = open( file, O_RDONLY | O_BINARY );
        if( loader_handle < 0 ) {
            print_strs("Error opening file '", file, "'\r\n", NULL);
            exit( 1 );
        }
        size = filelength( loader_handle );
        loader_code = calloc( (size + 3) & -4L, 1 );
        if( loader_code == NULL ) { oom:
            print_str( "Out of memory\r\n" );
            return( -1 );
        }
        len = read( loader_handle, loader_code, size );
        close( loader_handle );
        if( len != size ) {
            print_strs("Error reading '", file, "'\r\n", NULL);
            exit( 1 );
        }
        size = (size + 3) & -4L;        /* round up to multiple of 4 */
        /* patch header in the loader */
        dos_header = (dos_hdr *)loader_code;
        w32_header = (w32_hdr *)
            (size >= 0x38 && is_all_zero_bytes(loader_code + 0x20, 0x18) && dos_header->size_of_DOS_header_in_paras >= 4 ? loader_code + 0x20 :
             loader_code + ((DWORD)dos_header->size_of_DOS_header_in_paras << 4));
        fix_pmode_w(loader_code, size);
    }

    w32_header->start_of_W32_file = size;
    w32_header->size_of_W32_file = codesize + relocsize;
    w32_header->offset_to_relocs = codesize;
    if (w32_header->size_of_W32_file > maxmem) maxmem = w32_header->size_of_W32_file;
    maxmem = Align4K( maxmem );
    w32_header->memory_size = maxmem;
    w32_header->initial_EIP = exehdr.hdr.initial_eip;
    w32_header->sig = 'FC';
    len = write( newfile, loader_code, size );
    if( len != size ) {
        print_str( "Error writing output file\r\n" );
        close( newfile );
        close( handle );
        exit( 1 );
    }
    lseek( handle, exelen + file_header_size, SEEK_SET );
    CopyRexFile( handle, newfile, codesize );
    close( handle );
    len = write( newfile, RelocBuffer, relocsize );
    if( len != relocsize ) {
        print_str( "Error writing output file\r\n" );
        close( newfile );
        exit( 1 );
    }
    if( relsize != 0 ) {
        free( relocs );
    }
    free( RelocBuffer );
    close( newfile );
    return( 0 );
}
