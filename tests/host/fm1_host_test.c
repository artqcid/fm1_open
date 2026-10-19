/* SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception */
/* Host-side checks for APP persistence logic (T-29).
 *
 * Builds app/project.c and app/samples.c against a RAM-backed Flash and the
 * binary engine's control stubs. This is intentionally a plain main(): no test
 * framework, no external dependencies. Artifacts belong in %TEMP%\opencode.
 */
#include "instrument.h"
#include "fm1_device.h"
#include "fm_patch.h"
#include "sampledrum.h"
#include "tuning_hook.h"
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint8_t flash[GROOVE_FLASH_BYTES];
static uint32_t millis;
static unsigned tuning_capture_calls, tuning_apply_calls;
static unsigned arrangement_apply_calls, edit_checkpoint_calls, project_apply_calls;
static struct groove_tuning last_tuning[GROOVE_TRACKS];

static int failures;

#define CHECK(cond, text)                                                        \
    do {                                                                         \
        if (!(cond)) {                                                           \
            fprintf(stderr, "FAIL: %s (%s:%d)\n", text, __FILE__, __LINE__);     \
            ++failures;                                                          \
        }                                                                        \
    } while (0)

static void reset_flash(void)
{
    memset(flash, 0xff, sizeof flash);
    millis = 0;
    tuning_capture_calls = tuning_apply_calls = 0;
    arrangement_apply_calls = edit_checkpoint_calls = project_apply_calls = 0;
    memset(last_tuning, 0, sizeof last_tuning);
}

/* ---- board / Flash services --------------------------------------------- */

uint32_t fm1_flash_size(void) { return sizeof flash; }

int fm1_flash_read(uint32_t offset, void *data, size_t bytes)
{
    if (!data || offset > sizeof flash || bytes > sizeof flash - offset)
        return FM1_FLASH_INVALID;
    memcpy(data, flash + offset, bytes);
    return FM1_FLASH_OK;
}

int fm1_flash_write(uint32_t offset, const void *data, size_t bytes)
{
    if (!data || offset > sizeof flash || bytes > sizeof flash - offset)
        return FM1_FLASH_INVALID;
    memcpy(flash + offset, data, bytes);
    return FM1_FLASH_OK;
}

int fm1_flash_erase(uint32_t offset)
{
    if (offset % FM1_FLASH_SECTOR_BYTES || offset > sizeof flash - FM1_FLASH_SECTOR_BYTES)
        return FM1_FLASH_INVALID;
    memset(flash + offset, 0xff, FM1_FLASH_SECTOR_BYTES);
    return FM1_FLASH_OK;
}

const uint8_t *fm1_flash_map(uint32_t offset, size_t bytes)
{
    if (offset > sizeof flash || bytes > sizeof flash - offset)
        return NULL;
    return flash + offset;
}

int fm1_flash_invalidate(uint32_t offset, size_t bytes)
{
    (void)offset;
    (void)bytes;
    return FM1_FLASH_OK;
}

uint32_t fm1_millis(void) { return ++millis; }

/* ---- engine / APP stubs -------------------------------------------------- */

void fm1_engine_pause(void) {}
void fm1_engine_resume(void) {}
void fm1_engine_stop(void) {}

int sampledrum_bind(unsigned pad, const uint8_t *data, unsigned bytes, unsigned frames,
                    const char *name)
{
    (void)pad;
    (void)data;
    (void)bytes;
    (void)frames;
    (void)name;
    return 0;
}

void groove_samples_stop(void) {}

int fm1_ble_set_role(enum fm1_ble_role role)
{
    (void)role;
    return 0;
}

int fm1_bluetooth_configure(unsigned features)
{
    (void)features;
    return 0;
}

unsigned fm1_midi_input_ports(void) { return 7U; }
unsigned fm1_midi_output_ports(void) { return 1U; }

void groove_midi_defaults(struct groove_midi_config *config)
{
    memset(config, 0, sizeof *config);
}

int groove_midi_config_valid(const struct groove_midi_config *config)
{
    (void)config;
    return 1;
}

void groove_midi_config_read(struct groove_midi_config *config)
{
    memset(config, 0, sizeof *config);
}

void groove_midi_config_apply(const struct groove_midi_config *config)
{
    (void)config;
}

unsigned groove_midi_input_channel(unsigned track) { return track; }

int groove_midi_input_set(unsigned track, unsigned channel)
{
    (void)track;
    (void)channel;
    return 0;
}

unsigned groove_midi_setting(unsigned track, unsigned parameter)
{
    (void)track;
    (void)parameter;
    return 0;
}

unsigned groove_track_role(unsigned track) { return track; }

int groove_track_role_set(unsigned track, unsigned role)
{
    (void)track;
    (void)role;
    return 0;
}

void groove_clock_set(unsigned mode) { (void)mode; }

void groove_project_arp_defaults(struct groove_project *p) { (void)p; }

void groove_edit_checkpoint(unsigned operation)
{
    (void)operation;
    ++edit_checkpoint_calls;
}

void groove_edit_record(unsigned enabled, unsigned track, unsigned step)
{
    (void)enabled;
    (void)track;
    (void)step;
}

int groove_factory_build(unsigned index, struct groove_project *p)
{
    (void)index;
    memset(p, 0, sizeof *p);
    memcpy(p->name, "FACTORY", 7);
    p->sequence.version = 4;
    return 0;
}

int groove_fm_library_recover(void) { return 0; }
void groove_fm_library_init(void) {}

int groove_project_apply(const struct groove_project *p)
{
    (void)p;
    ++project_apply_calls;
    return 0;
}

/* -fno-weak turns project.c's optional hook into a normal reference. */
int groove_project_apply_edit(const struct groove_project *p, unsigned operation)
{
    (void)operation;
    return groove_project_apply(p);
}

int groove_project_valid(const struct groove_project *p)
{
    (void)p;
    return 1;
}

void groove_project_clean(void) {}
void groove_project_touch(void) {}

int groove_arrangement_capture(struct groove_project *p)
{
    memset(p, 0, sizeof *p);
    memcpy(p->name, "HOSTTEST", 8);
    p->sequence.version = 4;
    return 0;
}

int groove_tuning_capture(struct groove_tuning t[GROOVE_TRACKS])
{
    ++tuning_capture_calls;
    memset(t, 0, sizeof(struct groove_tuning) * GROOVE_TRACKS);
    return 0;
}

int groove_tuning_apply(const struct groove_tuning t[GROOVE_TRACKS])
{
    (void)t;
    ++tuning_apply_calls;
    return 0;
}

int groove_arrangement_tuning_capture(struct groove_tuning t[GROOVE_TRACKS])
{
    memset(t, 0, sizeof(struct groove_tuning) * GROOVE_TRACKS);
    return 0;
}

int groove_arrangement_tuning_apply(const struct groove_tuning t[GROOVE_TRACKS])
{
    memcpy(last_tuning, t, sizeof last_tuning);
    ++arrangement_apply_calls;
    return 0;
}

/* ---- test helpers -------------------------------------------------------- */

struct host_header { uint32_t magic, generation, target, crc, commit; };
_Static_assert(sizeof(struct host_header) == 20, "project header layout");

struct host_tuning_block {
    uint32_t magic;
    struct groove_tuning t[GROOVE_TRACKS];
    uint32_t crc;
};

struct host_sample_entry { uint32_t offset, frames, bytes; char name[16]; };
struct host_sample_header {
    uint32_t magic, version, bytes, crc, commit, rate, reserved[2];
    struct host_sample_entry entry[16];
    uint8_t padding[32];
};
_Static_assert(sizeof(struct host_sample_header) == 512, "sample header layout");

static uint32_t legacy_crc(const struct host_header *h, const struct groove_project *p,
                           const uint8_t settings[4])
{
    uint32_t crc = groove_crc32(~0U, h, offsetof(struct host_header, crc));
    crc = groove_crc32(crc, settings, 4);
    return ~groove_crc32(crc, p, GROOVE_PROJECT_LEGACY_BYTES);
}

static uint32_t tuning_block_crc(const struct host_tuning_block *b)
{
    return ~groove_crc32(~0U, b, offsetof(struct host_tuning_block, crc));
}

static uint32_t sample_crc(const struct host_sample_header *h, const uint8_t *data,
                           unsigned bytes)
{
    static const uint8_t zero[8];
    uint32_t crc = groove_crc32(~0U, h, 12);
    crc = groove_crc32(crc, zero, sizeof zero);
    crc = groove_crc32(crc, (const uint8_t *)h + 20, sizeof *h - 20);
    return ~groove_crc32(crc, data, bytes);
}

/* ---- tests --------------------------------------------------------------- */

static void test_crc32(void)
{
    static const char vector[] = "123456789";
    CHECK(~groove_crc32(~0U, vector, 9) == 0xCBF43926U, "CRC-32/ISO-HDLC vector");
}

static void test_project_roundtrip(void)
{
    reset_flash();
    CHECK(groove_project_save_slot(0) == 0, "project save");
    CHECK(*(const uint32_t *)flash == 0x36504d46U, "project magic");
    CHECK(*(const uint32_t *)(flash + offsetof(struct host_header, commit)) == 0,
          "project commit word");

    char name[13];
    CHECK(groove_project_info(0, name) == 0 && strcmp(name, "HOSTTEST") == 0,
          "project info");
    CHECK(groove_project_load_slot(0) == 0, "project load");
    CHECK(strcmp(groove_project_scratch()->name, "HOSTTEST") == 0, "project roundtrip");
    CHECK(groove_project_scratch()->sequence.version == 4, "project version");

    /* The staging sector holds a recovery copy. Remove it, then break the
     * payload CRC so only the checksum path can reject the record. */
    memset(flash + 16 * FM1_FLASH_SECTOR_BYTES, 0xff, FM1_FLASH_SECTOR_BYTES);
    flash[offsetof(struct host_header, commit) + 20 + 100] ^= 1U;
    CHECK(groove_project_load_slot(0) == GROOVE_PROJECT_EMPTY,
          "corrupt project rejected");
}

static void test_legacy_upgrade(void)
{
    reset_flash();
    struct host_header h = {0x34504d46U, 7U, 1U, 0U, 0U};
    struct groove_project p;
    memset(&p, 0, sizeof p);
    p.sequence.version = 3;
    memcpy(p.name, "LEGACY", 6);
    const uint8_t settings[4] = {0, 0, 0, 0};
    h.crc = legacy_crc(&h, &p, settings);

    uint8_t *sector = flash + FM1_FLASH_SECTOR_BYTES;
    memcpy(sector, &h, sizeof h);
    memcpy(sector + sizeof h, &p, GROOVE_PROJECT_LEGACY_BYTES);
    memcpy(sector + sizeof h + GROOVE_PROJECT_LEGACY_BYTES, settings, sizeof settings);

    CHECK(groove_project_load_slot(1) == 0, "legacy load");
    CHECK(groove_project_scratch()->sequence.version == 4, "legacy upgraded to v4");
    CHECK(memcmp(groove_project_scratch()->name, "LEGACY", 6) == 0, "legacy name");
}

static void test_tuning_import(void)
{
    reset_flash();
    uint8_t *buffer = malloc(GROOVE_PROJECT_TUNED_BYTES);
    CHECK(buffer != NULL, "tuning buffer allocation");
    if (!buffer)
        return;

    struct groove_project *p = (struct groove_project *)buffer;
    memset(p, 0, sizeof *p);
    memcpy(p->name, "TUNED", 5);
    p->sequence.version = 4;

    struct host_tuning_block *block =
        (struct host_tuning_block *)(buffer + GROOVE_PROJECT_BYTES);
    memset(block, 0, sizeof *block);
    block->magic = 0x54314d46U;
    block->t[0].main[0] = -128;
    block->crc = tuning_block_crc(block);

    unsigned before = arrangement_apply_calls;
    CHECK(groove_project_import(buffer, GROOVE_PROJECT_TUNED_BYTES) ==
              GROOVE_PROJECT_INVALID,
          "reject -128 tuning");
    CHECK(arrangement_apply_calls == before, "no apply after rejected tuning");

    block->t[0].main[0] = 5;
    block->t[0].alt[11] = -127;
    block->t[7].main[3] = 12;
    block->crc = tuning_block_crc(block);

    CHECK(groove_project_import(buffer, GROOVE_PROJECT_TUNED_BYTES) == 0,
          "accept valid tuning");
    CHECK(arrangement_apply_calls == before + 1, "apply all-or-nothing block");
    CHECK(last_tuning[0].main[0] == 5 && last_tuning[0].alt[11] == -127 &&
              last_tuning[7].main[3] == 12,
          "all tuning tables transferred");
    free(buffer);
}

static int write_sample_bank(const struct host_sample_header *h, const uint8_t *frame)
{
    if (groove_samples_begin(h->bytes))
        return -1;
    const uint8_t *header = (const uint8_t *)h;
    for (unsigned offset = 0; offset < sizeof *h; offset += 128) {
        unsigned bytes = sizeof *h - offset;
        if (bytes > 128)
            bytes = 128;
        if (groove_samples_write(offset, header + offset, bytes))
            return -1;
    }
    if (groove_samples_write(sizeof *h, frame, 128))
        return -1;
    if (groove_samples_write(sizeof *h + 128, frame + 128, 100))
        return -1;
    return groove_samples_finish();
}

static void test_samples(void)
{
    reset_flash();
    groove_samples_init();
    CHECK(groove_samples_status() == 1, "samples init validating");

    const unsigned total = 512 + 228;
    struct host_sample_header h;
    memset(&h, 0, sizeof h);
    h.magic = 0x53314d46U;
    h.version = 1;
    h.bytes = total;
    h.rate = 32000;
    h.entry[0].offset = 512;
    h.entry[0].frames = 320;
    h.entry[0].bytes = 228;
    memcpy(h.entry[0].name, "TEST", 4);
    for (unsigned i = 1; i < 16; ++i)
        h.entry[i].offset = total;

    uint8_t frame[228];
    memset(frame, 0, sizeof frame);
    frame[0] = 1;
    frame[1] = 0x45;
    frame[2] = 20;
    frame[3] = 0x5a;
    h.crc = sample_crc(&h, frame, sizeof frame);

    CHECK(write_sample_bank(&h, frame) == 0, "samples finish");
    CHECK(groove_samples_status() == 2, "samples ready");
    CHECK(groove_samples_size() == total, "samples size");

    uint8_t readback[64];
    CHECK(groove_samples_read(0, readback, sizeof readback) == 0, "samples read");
    CHECK(memcmp(readback, &h, sizeof readback) == 0, "samples header readback");

    reset_flash();
    groove_samples_init();
    h.crc = 0; /* deliberately wrong */
    CHECK(write_sample_bank(&h, frame) == GROOVE_PROJECT_INVALID,
          "reject bad sample CRC");

    reset_flash();
    groove_samples_init();
    CHECK(groove_samples_begin(total) == 0, "samples begin for order check");
    CHECK(groove_samples_write(128, frame, 128) == GROOVE_PROJECT_INVALID,
          "reject out-of-order sample write");
}

int main(void)
{
    test_crc32();
    test_project_roundtrip();
    test_legacy_upgrade();
    test_tuning_import();
    test_samples();

    if (failures) {
        fprintf(stderr, "%d host check(s) failed\n", failures);
        return 1;
    }
    printf("host checks passed\n");
    return 0;
}
