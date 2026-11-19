// Secret.h — shared API between Tweak.mm (il2cpp + cheat logic) and Build.mm (menu UI).
#pragma once

#include <string>
#include <vector>

namespace secret {

// Order matches the menu rows and CurrencyManager getters (TOJGAMES.Economy).
enum Currency : int {
    kGold = 0,
    kSilver,
    kKeys,
    kTickets,
    kLapis,
    kXP,
    kCurrencyCount
};

struct State {
    bool  infiniteCurrency = false;
    bool  noDamage         = false;
    bool  infFuel          = false;
    bool  noHeat           = false;
    bool  maxGrip          = false;
    bool  speedBoost       = false;
    float speedMult        = 1.5f;
};

struct CarInfo {
    int         id;
    std::string name;
    int         carClass; // 0=None, 1=D, 2=C, 3=B, 4=A, 5=S
    int         pp;
    int         type;     // Car.Type (0..7)
    bool        owned;
};

State& state();

bool ready();                              // il2cpp up + CurrencyManager reachable
int  getBalance(Currency c);               // -1 on failure
bool addBalance(Currency c, int amount);   // CurrencyBase.Earn, capped
bool setBalance(Currency c, int amount);   // CurrencyBase.SetBalance
bool hasVehicle();                         // RCC_SceneManager.activePlayerVehicle alive
bool repairVehicle();                      // RCC_CarControllerV3.repairNow = true
void startTick();                          // main-thread NSTimer, re-applies toggles

bool                 garageReady();
int                  currentGarageCarId();
std::vector<CarInfo> listCars();
bool                 unlockAndEquipCar(int carId, std::string* outName = nullptr);
bool                 unlockCurrentCar(std::string* outName = nullptr);
int                  unlockAllCars(); // returns count unlocked, -1 if not ready

} // namespace secret
