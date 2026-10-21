#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <fdi.h>
#include <objbase.h>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <unordered_map>

namespace fs = std::filesystem;

namespace {
const BYTE* cabinetBytes = nullptr;
DWORD cabinetSize = 0;
struct CabinetReader { long position = 0; };
std::unordered_map<INT_PTR, CabinetReader*> cabinetReaders;

struct TemporaryFolder {
  fs::path parent;
  fs::path path;
  ~TemporaryFolder() {
    // Only remove the uniquely created direct child of the selected temp folder.
    if (!path.empty() && path.parent_path() == parent &&
        path.filename().wstring().find(L"OrientMark-QR-") == 0) {
      std::error_code error;
      fs::remove_all(path, error);
    }
  }
};

std::runtime_error windowsError(const char* operation) {
  return std::runtime_error(std::string(operation) + ": " + std::to_string(GetLastError()));
}

void createTemporaryFolder(TemporaryFolder& folder) {
  wchar_t buffer[32768];
  const DWORD length = GetTempPathW(32768, buffer);
  if (length == 0 || length >= 32768) throw windowsError("GetTempPathW");
  folder.parent = fs::path(buffer).lexically_normal();
  // Normalize away a trailing separator for the parent-path comparison.
  if (folder.parent.filename().empty()) folder.parent = folder.parent.parent_path();
  GUID guid;
  if (FAILED(CoCreateGuid(&guid))) throw std::runtime_error("Cannot create temporary folder ID");
  wchar_t id[40];
  StringFromGUID2(guid, id, 40);
  const auto target = folder.parent / (std::wstring(L"OrientMark-QR-") + id);
  if (!CreateDirectoryW(target.c_str(), nullptr)) throw windowsError("CreateDirectoryW");
  folder.path = target;
}

void FAR* DIAMONDAPI allocate(ULONG size) { return std::malloc(size); }
void DIAMONDAPI release(void FAR* pointer) { std::free(pointer); }

INT_PTR DIAMONDAPI openCabinet(char* name, int, int) {
  if (std::strcmp(name, "embedded.cab") != 0) return -1;
  auto* reader = new CabinetReader();
  const auto handle = reinterpret_cast<INT_PTR>(reader);
  cabinetReaders.emplace(handle, reader);
  return handle;
}

UINT DIAMONDAPI readCabinet(INT_PTR handle, void* buffer, UINT count) {
  const auto entry = cabinetReaders.find(handle);
  if (entry == cabinetReaders.end()) return static_cast<UINT>(-1);
  auto& position = entry->second->position;
  const auto remaining = cabinetSize - static_cast<DWORD>(position);
  const auto bytes = std::min<UINT>(count, remaining);
  std::memcpy(buffer, cabinetBytes + position, bytes);
  position += static_cast<long>(bytes);
  return bytes;
}

UINT DIAMONDAPI writeFile(INT_PTR handle, void* buffer, UINT count) {
  DWORD written = 0;
  if (!WriteFile(reinterpret_cast<HANDLE>(handle), buffer, count, &written, nullptr))
    return static_cast<UINT>(-1);
  return written;
}

int DIAMONDAPI closeFile(INT_PTR handle) {
  const auto entry = cabinetReaders.find(handle);
  if (entry != cabinetReaders.end()) {
    delete entry->second;
    cabinetReaders.erase(entry);
    return 0;
  }
  return CloseHandle(reinterpret_cast<HANDLE>(handle)) ? 0 : -1;
}

long DIAMONDAPI seekCabinet(INT_PTR handle, long offset, int origin) {
  const auto entry = cabinetReaders.find(handle);
  if (entry == cabinetReaders.end()) return -1;
  const long long start = origin == SEEK_SET ? 0 : origin == SEEK_CUR ? entry->second->position : cabinetSize;
  const auto position = start + offset;
  if (position < 0 || position > cabinetSize) return -1;
  entry->second->position = static_cast<long>(position);
  return entry->second->position;
}

INT_PTR DIAMONDAPI extractFile(FDINOTIFICATIONTYPE type, PFDINOTIFICATION notification) {
  if (type == fdintCLOSE_FILE_INFO) return closeFile(notification->hf) == 0 ? TRUE : FALSE;
  if (type == fdintNEXT_CABINET) return -1;
  if (type != fdintCOPY_FILE) return 0;
  try {
    const auto* folder = static_cast<TemporaryFolder*>(notification->pv);
    // This project's resource names are UTF-8 (the current assets are ASCII).
    const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, notification->psz1, -1, nullptr, 0);
    if (length < 2) return -1;
    std::wstring name(length, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, notification->psz1, -1, name.data(), length);
    name.pop_back();
    const fs::path relative(name);
    if (relative.is_absolute() || relative.has_root_path()) return -1;
    for (const auto& part : relative) {
      if (part == L".." || part == L"." || part.wstring().find(L':') != std::wstring::npos) return -1;
    }
    const auto target = folder->path / relative;
    fs::create_directories(target.parent_path());
    const HANDLE file = CreateFileW(target.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    return file == INVALID_HANDLE_VALUE ? -1 : reinterpret_cast<INT_PTR>(file);
  } catch (...) { return -1; }
}

void unpack(HINSTANCE instance, TemporaryFolder& folder) {
  const HRSRC resource = FindResourceW(instance, MAKEINTRESOURCEW(101), RT_RCDATA);
  if (!resource) throw windowsError("FindResourceW");
  const HGLOBAL loaded = LoadResource(instance, resource);
  cabinetBytes = static_cast<const BYTE*>(LockResource(loaded));
  cabinetSize = SizeofResource(instance, resource);
  if (!cabinetBytes || cabinetSize == 0) throw std::runtime_error("Empty application resource");
  ERF error = {};
  const HFDI extractor = FDICreate(allocate, release, openCabinet, readCabinet, writeFile, closeFile, seekCabinet, cpuUNKNOWN, &error);
  if (!extractor) throw std::runtime_error("Cannot initialize CAB extraction");
  char name[] = "embedded.cab";
  char directory[] = "";
  const BOOL success = FDICopy(extractor, name, directory, 0, extractFile, nullptr, &folder);
  FDIDestroy(extractor);
  if (!success) throw std::runtime_error("Cannot extract application, CAB error " + std::to_string(error.erfOper));
}
}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR arguments, int) {
  const bool diagnostics = std::wstring(arguments) == L"--diagnostics";
  try {
    TemporaryFolder folder;
    createTemporaryFolder(folder);
    unpack(instance, folder);
    const auto executable = folder.path / L"orientmark_qr.exe";
    std::wstring command = L"\"" + executable.wstring() + L"\"";
    STARTUPINFOW startup = {};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process = {};
    if (!CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, FALSE, 0, nullptr, folder.path.c_str(), &startup, &process))
      throw windowsError("CreateProcessW");
    CloseHandle(process.hThread);
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = 0;
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hProcess);
    return static_cast<int>(exitCode);
  } catch (const std::exception& error) {
    if (diagnostics) {
      wchar_t temporary[32768];
      if (GetTempPathW(32768, temporary)) {
        const auto log = fs::path(temporary) / L"portable-error.txt";
        const HANDLE file = CreateFileW(log.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file != INVALID_HANDLE_VALUE) {
          DWORD written;
          WriteFile(file, error.what(), static_cast<DWORD>(std::strlen(error.what())), &written, nullptr);
          CloseHandle(file);
        }
      }
      return 1;
    }
    const std::wstring detail(error.what(), error.what() + std::strlen(error.what()));
    const auto message = std::wstring(L"Cannot start OrientMark QR.\n\n") + detail;
    MessageBoxW(nullptr, message.c_str(), L"OrientMark QR", MB_OK | MB_ICONERROR);
    return 1;
  }
}
