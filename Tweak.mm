// Tweak.mm — il2cpp bridge + cheat logic.
// No inline hooks: only exported il2cpp_* API calls and managed-field writes,
// so it works on stock iOS sideload (no JIT, no jailbreak, no text-page patching).
// Classes/fields are resolved by name at runtime -> survives RVA shifts between game updates.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>
#include "Secret.h"

// ===== config =====
static constexpr int         kMaxBalance    = 999999999;
static constexpr int         kInfiniteFloor = 1000000;   // infinite mode refills below this
static constexpr double      kTickSec       = 0.25;
static constexpr int         kCurrencyEvery = 4;         // ticks between infinite-currency checks (~1s)
static constexpr float       kGripValue     = 1.5f;      // RCC Range(0.3, 1.5)
static constexpr float       kSafeHeat      = 15.0f;     // RCC ambient engine heat
static constexpr double      kInitDelaySec  = 3.0;
static constexpr size_t      kCachedPtrOff  = 0x10;      // UnityEngine.Object::m_CachedPtr
static constexpr size_t      kMaxCarCount   = 8192;
static constexpr int32_t     kMaxStringLen  = 512;
static constexpr int         kCarComingSoon = 8;         // TOJGAMES.Car.Type.ComingSoon
static constexpr const char* kGameImage     = "Assembly-CSharp.dll";
static constexpr const char* kCoreImage     = "UnityEngine.CoreModule.dll";

extern "C" void SecretMenuInit(void);

namespace {

// ---------------------------------------------------------------- il2cpp api
struct Il2Cpp {
    void*       (*domain_get)();
    void*       (*thread_attach)(void*);
    void**      (*domain_get_assemblies)(void*, size_t*);
    void*       (*assembly_get_image)(void*);
    const char* (*image_get_name)(void*);
    void*       (*class_from_name)(void*, const char*, const char*);
    void*       (*class_get_method_from_name)(void*, const char*, int);
    void*       (*class_get_field_from_name)(void*, const char*);
    size_t      (*field_get_offset)(void*);
    void        (*field_static_get_value)(void*, void*);
    void*       (*object_get_virtual_method)(void*, void*);
    void*       (*runtime_invoke)(void*, void*, void**, void**);
    void*       (*object_unbox)(void*);
    void        (*runtime_class_init)(void*);
    bool ok = false;

    // optional symbols used for garage arrays/strings/object lookup
    uint32_t        (*array_length)(void*)             = nullptr;
    const uint16_t* (*string_chars)(void*)             = nullptr;
    int32_t         (*string_length)(void*)            = nullptr;
    const void*     (*class_get_type)(void*)           = nullptr;
    void*           (*type_get_object)(const void*)    = nullptr;
    void*           (*class_get_methods)(void*, void**)= nullptr;
    const char*     (*method_get_name)(void*)          = nullptr;
    uint32_t        (*method_get_param_count)(void*)   = nullptr;
    bool            (*method_is_generic)(void*)        = nullptr;
} il;

template <typename T>
bool sym(T& out, const char* name) {
    out = reinterpret_cast<T>(dlsym(RTLD_DEFAULT, name));
    return out != nullptr;
}

bool loadApi() {
    if (il.ok) return true;
    il.ok = sym(il.domain_get,                 "il2cpp_domain_get")
         && sym(il.thread_attach,              "il2cpp_thread_attach")
         && sym(il.domain_get_assemblies,      "il2cpp_domain_get_assemblies")
         && sym(il.assembly_get_image,         "il2cpp_assembly_get_image")
         && sym(il.image_get_name,             "il2cpp_image_get_name")
         && sym(il.class_from_name,            "il2cpp_class_from_name")
         && sym(il.class_get_method_from_name, "il2cpp_class_get_method_from_name")
         && sym(il.class_get_field_from_name,  "il2cpp_class_get_field_from_name")
         && sym(il.field_get_offset,           "il2cpp_field_get_offset")
         && sym(il.field_static_get_value,     "il2cpp_field_static_get_value")
         && sym(il.object_get_virtual_method,  "il2cpp_object_get_virtual_method")
         && sym(il.runtime_invoke,             "il2cpp_runtime_invoke")
         && sym(il.object_unbox,               "il2cpp_object_unbox")
         && sym(il.runtime_class_init,         "il2cpp_runtime_class_init");
    if (il.ok) {
        sym(il.array_length,           "il2cpp_array_length");
        sym(il.string_chars,           "il2cpp_string_chars");
        sym(il.string_length,          "il2cpp_string_length");
        sym(il.class_get_type,         "il2cpp_class_get_type");
        sym(il.type_get_object,        "il2cpp_type_get_object");
        sym(il.class_get_methods,      "il2cpp_class_get_methods");
        sym(il.method_get_name,        "il2cpp_method_get_name");
        sym(il.method_get_param_count, "il2cpp_method_get_param_count");
        sym(il.method_is_generic,      "il2cpp_method_is_generic");
    }
    return il.ok;
}

// ---------------------------------------------------------------- resolved refs
constexpr const char* kGetterNames[secret::kCurrencyCount] = {
    "get_GoldCurrency",
    "get_SilverCurrency",
    "get_KeyCurrency",
    "get_TicketCurrency",
    "get_LapisLazuliCurrency",
    "get_ExperienceCurrency",
};

struct CarOffsets {
    size_t useDamage, repairNow;
    size_t maxspeed, maxEngineTorque;
    size_t tireForwardGrip, drivenWheelGrip;
    size_t useFuelConsumption, fuelTankCapacity, fuelTank;
    size_t useEngineHeat, engineHeat;
};

struct GarageRefs {
    bool   carsOk = false;
    void*  mCarsInstance     = nullptr;
    void*  mGetSelectedCarId = nullptr;
    void*  mSetSelectedCarId = nullptr;
    void*  mGetCarById       = nullptr;
    size_t oCarsArray        = 0;

    size_t oCarId         = 0;
    size_t oCarName       = 0;
    size_t oCarEditorName = 0;
    size_t oCarPrefabPath = 0;
    size_t oCarType       = 0;
    size_t oCarUnlocked   = 0;
    size_t oCarPurchased  = 0;
    size_t oCarClass      = 0;
    size_t oCarPP         = 0;
    bool   hasCarBools    = false;
    bool   hasCarMeta     = false;
    void*  mCarGetPurchased = nullptr;
    void*  mCarSetUnlocked  = nullptr;
    void*  mCarSetPurchased = nullptr;

    bool   garageOk        = false;
    void*  fGarageInstance = nullptr;
    size_t oGarageActiveId = 0;
    void*  mGarageSpawn    = nullptr;

    void*  kSelectionScreen  = nullptr;
    size_t oSelListMgr       = 0;
    size_t oSelActiveId      = 0;
    size_t oSelActiveCar     = 0;
    bool   hasSelListMgr     = false;
    bool   hasSelActiveId    = false;
    bool   hasSelActiveCar   = false;
    void*  mSelUpdateView    = nullptr;
    void*  mListUpdateList   = nullptr;
    void*  mFindObjectOfType = nullptr;
};

struct Refs {
    bool   ok = false;
    void*  mInstance = nullptr;
    void*  mGetter[secret::kCurrencyCount] = {};
    void*  mEarn = nullptr;
    void*  mSet  = nullptr;
    void*  mGet  = nullptr;
    bool   carOk = false;
    void*  fRccInstance   = nullptr;
    size_t oActiveVehicle = 0;
    CarOffsets car{};
    GarageRefs g{};
} R;

void* method(void* k, const char* n, int argc) {
    return k ? il.class_get_method_from_name(k, n, argc) : nullptr;
}

bool fieldOffset(void* k, const char* n, size_t& out) {
    void* f = k ? il.class_get_field_from_name(k, n) : nullptr;
    if (!f) return false;
    out = il.field_get_offset(f);
    return true;
}

void* imageByName(void* dom, const char* target) {
    size_t n = 0;
    void** as = il.domain_get_assemblies(dom, &n);
    for (size_t i = 0; as && i < n; ++i) {
        void* img = il.assembly_get_image(as[i]);
        const char* nm = img ? il.image_get_name(img) : nullptr;
        if (nm && std::strcmp(nm, target) == 0) return img;
    }
    return nullptr;
}

bool resolve() {
    if (R.ok) { il.thread_attach(il.domain_get()); return true; }
    if (!loadApi()) return false;
    void* dom = il.domain_get();
    if (!dom) return false;
    il.thread_attach(dom);
    void* img = imageByName(dom, kGameImage);
    if (!img) return false;

    // TOJGAMES.Economy — dump.cs TypeDefIndex 2049 / 2057
    void* mgr  = il.class_from_name(img, "TOJGAMES.Economy", "CurrencyManager");
    void* base = il.class_from_name(img, "TOJGAMES.Economy", "CurrencyBase");
    if (!mgr || !base) return false;

    R.mInstance = method(mgr, "get_Instance", 0);
    for (int i = 0; i < secret::kCurrencyCount; ++i) {
        R.mGetter[i] = method(mgr, kGetterNames[i], 0);
        if (!R.mGetter[i]) return false;
    }
    R.mEarn = method(base, "Earn", 1);
    R.mSet  = method(base, "SetBalance", 1);
    R.mGet  = method(base, "GetBalance", 0);
    if (!R.mInstance || !R.mEarn || !R.mSet || !R.mGet) return false;

    // Realistic Car Controller — dump.cs TypeDefIndex 186 / 257, global namespace
    void* rcc = il.class_from_name(img, "", "RCC_SceneManager");
    void* car = il.class_from_name(img, "", "RCC_CarControllerV3");
    if (rcc && car) {
        CarOffsets& o = R.car;
        R.fRccInstance = il.class_get_field_from_name(rcc, "instance");
        R.carOk = R.fRccInstance
               && fieldOffset(rcc, "activePlayerVehicle", R.oActiveVehicle)
               && fieldOffset(car, "useDamage",          o.useDamage)
               && fieldOffset(car, "repairNow",          o.repairNow)
               && fieldOffset(car, "maxspeed",           o.maxspeed)
               && fieldOffset(car, "maxEngineTorque",    o.maxEngineTorque)
               && fieldOffset(car, "tireForwardGrip",    o.tireForwardGrip)
               && fieldOffset(car, "drivenWheelGrip",    o.drivenWheelGrip)
               && fieldOffset(car, "useFuelConsumption", o.useFuelConsumption)
               && fieldOffset(car, "fuelTankCapacity",   o.fuelTankCapacity)
               && fieldOffset(car, "fuelTank",           o.fuelTank)
               && fieldOffset(car, "useEngineHeat",      o.useEngineHeat)
               && fieldOffset(car, "engineHeat",         o.engineHeat);
        // static_fields must exist before field_static_get_value
        if (R.carOk) il.runtime_class_init(rcc);
    }

    // TOJGAMES.CarsData / TOJGAMES.Car — dump.cs TypeDefIndex 1903 / 1904
    void* carsData = il.class_from_name(img, "TOJGAMES", "CarsData");
    void* carCls   = il.class_from_name(img, "TOJGAMES", "Car");
    if (carsData && carCls) {
        GarageRefs& g = R.g;
        g.mCarsInstance     = method(carsData, "get_Instance", 0);
        g.mGetSelectedCarId = method(carsData, "get_PlayerSelectedCarID", 0);
        g.mSetSelectedCarId = method(carsData, "set_PlayerSelectedCarID", 1);
        g.mGetCarById       = method(carsData, "GetCarByID", 1);
        g.mCarGetPurchased  = method(carCls, "get_IsPurchased", 0);
        g.mCarSetUnlocked   = method(carCls, "set_IsUnlocked", 1);
        g.mCarSetPurchased  = method(carCls, "set_IsPurchased", 1);
        g.carsOk = g.mCarsInstance && g.mGetSelectedCarId && g.mSetSelectedCarId
                && g.mGetCarById && g.mCarGetPurchased && g.mCarSetUnlocked && g.mCarSetPurchased
                && fieldOffset(carsData, "cars",       g.oCarsArray)
                && fieldOffset(carCls,   "id",         g.oCarId)
                && fieldOffset(carCls,   "name",       g.oCarName)
                && fieldOffset(carCls,   "editorName", g.oCarEditorName)
                && fieldOffset(carCls,   "prefabPath", g.oCarPrefabPath)
                && fieldOffset(carCls,   "type",       g.oCarType);
        g.hasCarBools = fieldOffset(carCls, "Unlocked",  g.oCarUnlocked)
                     && fieldOffset(carCls, "Purchased", g.oCarPurchased);
        g.hasCarMeta  = fieldOffset(carCls, "carClass",  g.oCarClass)
                     && fieldOffset(carCls, "pp",        g.oCarPP);
    }

    // GarageCarManager — dump.cs TypeDefIndex 826, global namespace
    void* garageCls = il.class_from_name(img, "", "GarageCarManager");
    if (garageCls) {
        GarageRefs& g = R.g;
        g.fGarageInstance = il.class_get_field_from_name(garageCls, "Instance");
        g.mGarageSpawn    = method(garageCls, "SpawnVehicleByID", 1);
        g.garageOk = g.fGarageInstance && g.mGarageSpawn
                  && fieldOffset(garageCls, "activeVehicleID", g.oGarageActiveId);
        if (g.garageOk) il.runtime_class_init(garageCls);
    }

    // CarSelectionScreen / CarsListManager + UnityEngine.Object.FindObjectOfType(Type)
    void* selCls  = il.class_from_name(img, "", "CarSelectionScreen");
    void* listCls = il.class_from_name(img, "", "CarsListManager");
    void* coreImg = imageByName(dom, kCoreImage);
    void* uObj    = coreImg ? il.class_from_name(coreImg, "UnityEngine", "Object") : nullptr;
    if (selCls && uObj && il.class_get_methods && il.method_get_name
        && il.method_get_param_count && il.method_is_generic
        && il.class_get_type && il.type_get_object) {
        void* iter = nullptr;
        while (void* m = il.class_get_methods(uObj, &iter)) {
            const char* nm = il.method_get_name(m);
            if (nm && std::strcmp(nm, "FindObjectOfType") == 0
                && il.method_get_param_count(m) == 1 && !il.method_is_generic(m)) {
                R.g.mFindObjectOfType = m;
                break;
            }
        }
        if (R.g.mFindObjectOfType) {
            GarageRefs& g = R.g;
            g.kSelectionScreen = selCls;
            g.mSelUpdateView   = method(selCls, "UpdateView", 0);
            g.hasSelListMgr    = fieldOffset(selCls, "listManager", g.oSelListMgr);
            g.hasSelActiveId   = fieldOffset(selCls, "activeCarID", g.oSelActiveId);
            g.hasSelActiveCar  = fieldOffset(selCls, "activeCar",   g.oSelActiveCar);
            if (listCls) g.mListUpdateList = method(listCls, "UpdateList", 0);
        }
    }

    R.ok = true;
    return true;
}

bool invoke(void* m, void* obj, void** args, void** ret = nullptr) {
    if (!m) return false;
    if (obj) {
        if (void* v = il.object_get_virtual_method(obj, m)) m = v;
    }
    void* exc = nullptr;
    void* r = il.runtime_invoke(m, obj, args, &exc);
    if (exc) return false;
    if (ret) *ret = r;
    return true;
}

void* currencyObj(secret::Currency c) {
    if (c < 0 || c >= secret::kCurrencyCount || !resolve()) return nullptr;
    void* mgr = nullptr;
    if (!invoke(R.mInstance, nullptr, nullptr, &mgr) || !mgr) return nullptr;
    void* cur = nullptr;
    if (!invoke(R.mGetter[c], mgr, nullptr, &cur)) return nullptr;
    return cur;
}

// ---------------------------------------------------------------- vehicle
inline bool alive(void* o) {
    return o && *reinterpret_cast<void**>(static_cast<uint8_t*>(o) + kCachedPtrOff) != nullptr;
}

template <typename T>
T& F(uint8_t* o, size_t off) { return *reinterpret_cast<T*>(o + off); }

uint8_t* activeVehicle() {
    if (!resolve() || !R.carOk) return nullptr;
    void* mgr = nullptr;
    il.field_static_get_value(R.fRccInstance, &mgr);
    if (!alive(mgr)) return nullptr;
    uint8_t* car = F<uint8_t*>(static_cast<uint8_t*>(mgr), R.oActiveVehicle);
    return alive(car) ? car : nullptr;
}

struct CarMem {
    float maxspeed, torque, grip, drivenGrip;
    bool  useDamage, useFuel, useHeat;
    bool  aDmg = false, aFuel = false, aHeat = false, aGrip = false, aSpeed = false;
};
std::unordered_map<uint8_t*, CarMem> g_cars;

void tickVehicle() {
    uint8_t* car = activeVehicle();
    if (!car) return;
    const CarOffsets& o = R.car;

    auto it = g_cars.find(car);
    if (it == g_cars.end()) {
        if (g_cars.size() > 32) g_cars.clear();
        CarMem m{};
        m.maxspeed   = F<float>(car, o.maxspeed);
        m.torque     = F<float>(car, o.maxEngineTorque);
        m.grip       = F<float>(car, o.tireForwardGrip);
        m.drivenGrip = F<float>(car, o.drivenWheelGrip);
        m.useDamage  = F<bool>(car, o.useDamage);
        m.useFuel    = F<bool>(car, o.useFuelConsumption);
        m.useHeat    = F<bool>(car, o.useEngineHeat);
        it = g_cars.emplace(car, m).first;
    }
    CarMem& m = it->second;
    const secret::State& s = secret::state();

    if (s.noDamage)      { F<bool>(car, o.useDamage) = false; m.aDmg = true; }
    else if (m.aDmg)     { F<bool>(car, o.useDamage) = m.useDamage; m.aDmg = false; }

    if (s.infFuel) {
        F<bool>(car, o.useFuelConsumption) = false;
        F<float>(car, o.fuelTank) = F<float>(car, o.fuelTankCapacity);
        m.aFuel = true;
    } else if (m.aFuel)  { F<bool>(car, o.useFuelConsumption) = m.useFuel; m.aFuel = false; }

    if (s.noHeat) {
        F<bool>(car, o.useEngineHeat) = false;
        F<float>(car, o.engineHeat) = kSafeHeat;
        m.aHeat = true;
    } else if (m.aHeat)  { F<bool>(car, o.useEngineHeat) = m.useHeat; m.aHeat = false; }

    if (s.maxGrip) {
        F<float>(car, o.tireForwardGrip) = kGripValue;
        F<float>(car, o.drivenWheelGrip) = kGripValue;
        m.aGrip = true;
    } else if (m.aGrip) {
        F<float>(car, o.tireForwardGrip) = m.grip;
        F<float>(car, o.drivenWheelGrip) = m.drivenGrip;
        m.aGrip = false;
    }

    if (s.speedBoost) {
        F<float>(car, o.maxspeed)        = m.maxspeed * s.speedMult;
        F<float>(car, o.maxEngineTorque) = m.torque   * s.speedMult;
        m.aSpeed = true;
    } else if (m.aSpeed) {
        F<float>(car, o.maxspeed)        = m.maxspeed;
        F<float>(car, o.maxEngineTorque) = m.torque;
        m.aSpeed = false;
    }
}

void tickCurrency() {
    if (!secret::state().infiniteCurrency) return;
    for (int i = 0; i < secret::kCurrencyCount; ++i) {
        if (i == secret::kXP) continue;   // XP drives level math, don't loop it
        const auto c = static_cast<secret::Currency>(i);
        const int b = secret::getBalance(c);
        if (b >= 0 && b < kInfiniteFloor) secret::setBalance(c, kMaxBalance);
    }
}

// ---------------------------------------------------------------- garage
size_t arrayLen(void* arr) {
    if (!arr) return 0;
    const size_t len = il.array_length
        ? static_cast<size_t>(il.array_length(arr))
        : *reinterpret_cast<uintptr_t*>(static_cast<uint8_t*>(arr) + 0x18);
    return len <= kMaxCarCount ? len : 0;
}

void* arrayElem(void* arr, size_t i) {
    return reinterpret_cast<void**>(static_cast<uint8_t*>(arr) + 0x20)[i];
}

std::string managedString(void* s) {
    if (!s) return "";
    const int32_t len = il.string_length
        ? il.string_length(s)
        : *reinterpret_cast<int32_t*>(static_cast<uint8_t*>(s) + 0x10);
    if (len <= 0 || len > kMaxStringLen) return "";
    const uint16_t* chars = il.string_chars
        ? il.string_chars(s)
        : reinterpret_cast<const uint16_t*>(static_cast<uint8_t*>(s) + 0x14);
    if (!chars) return "";
    @autoreleasepool {
        NSString* ns = [NSString stringWithCharacters:chars length:static_cast<NSUInteger>(len)];
        const char* utf8 = ns.UTF8String;
        return utf8 ? std::string(utf8) : "";
    }
}

void* carsDataObj() {
    if (!resolve() || !R.g.carsOk) return nullptr;
    void* cd = nullptr;
    if (!invoke(R.g.mCarsInstance, nullptr, nullptr, &cd) || !alive(cd)) return nullptr;
    return cd;
}

void* findActiveObject(void* klass) {
    if (!klass || !R.g.mFindObjectOfType || !il.class_get_type || !il.type_get_object) return nullptr;
    const void* t = il.class_get_type(klass);
    void* typeObj = t ? il.type_get_object(t) : nullptr;
    if (!typeObj) return nullptr;
    void* args[1] = { typeObj }; // System.Type is a reference type
    void* res = nullptr;
    if (!invoke(R.g.mFindObjectOfType, nullptr, args, &res) || !alive(res)) return nullptr;
    return res;
}

bool isValidCar(uint8_t* car) {
    if (!car) return false;
    if (F<int>(car, R.g.oCarType) == kCarComingSoon) return false;
    return !managedString(F<void*>(car, R.g.oCarPrefabPath)).empty();
}

std::string carDisplayName(uint8_t* car, int id) {
    if (!car) return "Car #" + std::to_string(id);
    std::string n = managedString(F<void*>(car, R.g.oCarName));
    if (n.empty()) n = managedString(F<void*>(car, R.g.oCarEditorName));
    if (n.empty()) n = "Car #" + std::to_string(id);
    return n;
}

uint8_t* findCarById(uint8_t* cd, int carId) {
    if (!cd) return nullptr;
    int id = carId;
    void* args[1] = { &id };
    void* res = nullptr;
    if (invoke(R.g.mGetCarById, cd, args, &res) && res) return static_cast<uint8_t*>(res);
    void* arr = F<void*>(cd, R.g.oCarsArray);
    const size_t n = arrayLen(arr);
    for (size_t i = 0; i < n; ++i) {
        uint8_t* car = static_cast<uint8_t*>(arrayElem(arr, i));
        if (car && F<int>(car, R.g.oCarId) == carId) return car;
    }
    return nullptr;
}

bool unlockCarObj(uint8_t* car) {
    if (!car) return false;
    uint8_t t = 1;
    void* args[1] = { &t };
    const bool ok1 = invoke(R.g.mCarSetUnlocked, car, args);
    const bool ok2 = invoke(R.g.mCarSetPurchased, car, args);
    if (R.g.hasCarBools) {
        F<bool>(car, R.g.oCarUnlocked)  = true;
        F<bool>(car, R.g.oCarPurchased) = true;
    }
    return ok1 && ok2;
}

void refreshCarSelectionUI(int equipCarId, void* carObj) {
    uint8_t* scr = static_cast<uint8_t*>(findActiveObject(R.g.kSelectionScreen));
    if (!scr) return;
    if (equipCarId >= 0 && carObj) {
        if (R.g.hasSelActiveId)  F<int>(scr, R.g.oSelActiveId)   = equipCarId;
        if (R.g.hasSelActiveCar) F<void*>(scr, R.g.oSelActiveCar) = carObj;
    }
    if (R.g.hasSelListMgr && R.g.mListUpdateList) {
        void* listMgr = F<void*>(scr, R.g.oSelListMgr);
        if (alive(listMgr)) invoke(R.g.mListUpdateList, listMgr, nullptr);
    }
    if (R.g.mSelUpdateView) invoke(R.g.mSelUpdateView, scr, nullptr);
}

} // namespace

// ---------------------------------------------------------------- public api
namespace secret {

State& state() {
    static State s;
    return s;
}

bool ready() {
    return currencyObj(kGold) != nullptr;
}

int getBalance(Currency c) {
    void* cur = currencyObj(c);
    void* r = nullptr;
    if (!cur || !invoke(R.mGet, cur, nullptr, &r) || !r) return -1;
    return *static_cast<int*>(il.object_unbox(r));
}

bool setBalance(Currency c, int amount) {
    void* cur = currencyObj(c);
    if (!cur) return false;
    int v = amount < 0 ? 0 : (amount > kMaxBalance ? kMaxBalance : amount);
    void* args[1] = { &v };
    return invoke(R.mSet, cur, args);   // goes through ObscuredInt setter + NotifyBalanceUpdated
}

bool addBalance(Currency c, int amount) {
    if (amount <= 0) return false;
    void* cur = currencyObj(c);
    if (!cur) return false;
    const int now = getBalance(c);
    if (now >= 0 && static_cast<long long>(now) + amount > kMaxBalance) return setBalance(c, kMaxBalance);
    void* args[1] = { &amount };
    return invoke(R.mEarn, cur, args);
}

bool hasVehicle() {
    return activeVehicle() != nullptr;
}

bool repairVehicle() {
    uint8_t* car = activeVehicle();
    if (!car) return false;
    F<bool>(car, R.car.repairNow) = true;   // RCC repairs mesh/damage on next Update
    return true;
}

bool garageReady() {
    return carsDataObj() != nullptr;
}

int currentGarageCarId() {
    void* cd = carsDataObj();
    if (!cd) return -1;
    if (uint8_t* scr = static_cast<uint8_t*>(findActiveObject(R.g.kSelectionScreen))) {
        if (R.g.hasSelActiveId) {
            const int id = F<int>(scr, R.g.oSelActiveId);
            if (id >= 0) return id;
        }
    }
    if (R.g.garageOk) {
        void* gcm = nullptr;
        il.field_static_get_value(R.g.fGarageInstance, &gcm);
        if (alive(gcm)) {
            const int id = F<int>(static_cast<uint8_t*>(gcm), R.g.oGarageActiveId);
            if (id >= 0) return id;
        }
    }
    void* r = nullptr;
    if (invoke(R.g.mGetSelectedCarId, cd, nullptr, &r) && r)
        return *static_cast<int*>(il.object_unbox(r));
    return -1;
}

std::vector<CarInfo> listCars() {
    std::vector<CarInfo> out;
    uint8_t* cd = static_cast<uint8_t*>(carsDataObj());
    if (!cd) return out;
    void* arr = F<void*>(cd, R.g.oCarsArray);
    const size_t n = arrayLen(arr);
    out.reserve(n);
    for (size_t i = 0; i < n; ++i) {
        uint8_t* car = static_cast<uint8_t*>(arrayElem(arr, i));
        if (!isValidCar(car)) continue;
        CarInfo info{};
        info.id       = F<int>(car, R.g.oCarId);
        info.name     = carDisplayName(car, info.id);
        info.carClass = R.g.hasCarMeta ? F<int>(car, R.g.oCarClass) : 0;
        info.pp       = R.g.hasCarMeta ? F<int>(car, R.g.oCarPP)    : 0;
        info.type     = F<int>(car, R.g.oCarType);
        void* r = nullptr;
        if (invoke(R.g.mCarGetPurchased, car, nullptr, &r) && r)
            info.owned = (*static_cast<uint8_t*>(il.object_unbox(r))) != 0;
        out.push_back(std::move(info));
    }
    return out;
}

bool unlockAndEquipCar(int carId, std::string* outName) {
    uint8_t* cd = static_cast<uint8_t*>(carsDataObj());
    if (!cd) return false;
    uint8_t* car = findCarById(cd, carId);
    if (!isValidCar(car)) return false;
    if (outName) *outName = carDisplayName(car, carId);
    if (!unlockCarObj(car)) return false;

    int id = carId;
    void* args[1] = { &id };
    invoke(R.g.mSetSelectedCarId, cd, args);

    if (R.g.garageOk) {
        void* gcm = nullptr;
        il.field_static_get_value(R.g.fGarageInstance, &gcm);
        if (alive(gcm)) invoke(R.g.mGarageSpawn, gcm, args);
    }
    refreshCarSelectionUI(carId, car);
    return true;
}

bool unlockCurrentCar(std::string* outName) {
    const int id = currentGarageCarId();
    if (id < 0) return false;
    return unlockAndEquipCar(id, outName);
}

int unlockAllCars() {
    uint8_t* cd = static_cast<uint8_t*>(carsDataObj());
    if (!cd) return -1;
    void* arr = F<void*>(cd, R.g.oCarsArray);
    const size_t n = arrayLen(arr);
    int unlocked = 0;
    for (size_t i = 0; i < n; ++i) {
        uint8_t* car = static_cast<uint8_t*>(arrayElem(arr, i));
        if (!isValidCar(car)) continue;
        if (unlockCarObj(car)) ++unlocked;
    }
    refreshCarSelectionUI(-1, nullptr);
    return unlocked;
}

void startTick() {
    static NSTimer* timer = nil;
    if (timer) return;
    __block int n = 0;
    timer = [NSTimer timerWithTimeInterval:kTickSec repeats:YES block:^(NSTimer*) {
        @autoreleasepool {
            if (!resolve()) return;
            tickVehicle();
            if (++n % kCurrencyEvery == 0) tickCurrency();
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

} // namespace secret

// ---------------------------------------------------------------- entry
__attribute__((constructor)) static void xantapers_init() {
    // Unity on iOS runs its player loop on the main thread -> UI + il2cpp calls share it.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kInitDelaySec * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        SecretMenuInit();
        secret::startTick();
    });
}
