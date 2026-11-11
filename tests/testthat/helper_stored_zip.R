# Minimal stored (uncompressed) ZIP writer for synthetic test archives, with
# crafted member names and exact bytes. Sourced explicitly by test files.

# 32-bit unsigned XOR in two 16-bit halves (bitwXor is limited to signed int).
xor32 <- function(a, b) {
  bitwXor(a %/% 65536, b %/% 65536) * 65536 + bitwXor(a %% 65536, b %% 65536)
}
crc32_raw <- function(bytes) {
  table <- vapply(0:255, function(n) {
    c <- n
    for (k in 1:8) c <- if (c %% 2 == 1) xor32(0xEDB88320, c %/% 2) else c %/% 2
    c
  }, numeric(1))
  crc <- 0xFFFFFFFF
  for (b in as.integer(bytes)) crc <- xor32(table[(xor32(crc, b) %% 256) + 1L], crc %/% 256)
  xor32(crc, 0xFFFFFFFF)
}
le <- function(x, size) writeBin(as.integer(x), raw(), size = size, endian = "little")
le32 <- function(x) {
  x <- x %% 2^32
  as.raw(c(x %% 256, (x %/% 256) %% 256, (x %/% 65536) %% 256, x %/% 16777216))
}
write_stored_zip <- function(path, members) {
  local <- raw(); central <- raw(); offsets <- integer()
  for (name in names(members)) {
    data <- charToRaw(members[[name]]); fname <- charToRaw(name)
    crc <- crc32_raw(data)
    offsets <- c(offsets, length(local))
    local <- c(local, as.raw(c(0x50, 0x4b, 0x03, 0x04)), le(20, 2), le(0, 2), le(0, 2),
               le(0, 2), le(0, 2), le32(crc), le32(length(data)), le32(length(data)),
               le(length(fname), 2), le(0, 2), fname, data)
    central <- c(central, as.raw(c(0x50, 0x4b, 0x01, 0x02)), le(20, 2), le(20, 2), le(0, 2),
                 le(0, 2), le(0, 2), le(0, 2), le32(crc), le32(length(data)), le32(length(data)),
                 le(length(fname), 2), le(0, 2), le(0, 2), le(0, 2), le(0, 2), le32(0),
                 le32(utils::tail(offsets, 1)), fname)
  }
  end <- c(as.raw(c(0x50, 0x4b, 0x05, 0x06)), le(0, 2), le(0, 2), le(length(members), 2),
           le(length(members), 2), le32(length(central)), le32(length(local)), le(0, 2))
  writeBin(c(local, central, end), path)
  path
}
