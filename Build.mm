// Build.mm — UIKit mod menu.
// Floating button -> draggable panel: Creators / Hacks tabs, gear (settings) next to close,
// RU / EN / AR localization with RTL. Lives in Unity's key window, main thread only.
#import <UIKit/UIKit.h>
#include "Secret.h"

// ===== config =====
static NSString* const kTgHandle   = @"xantapers";
static NSString* const kModVersion = @"1.0";
static NSString* const kLangKey    = @"xantapers.mod.lang";
static const CGFloat   kPanelW     = 344;
static const CGFloat   kPanelMaxH  = 480;
static const CGFloat   kHeaderH    = 52;
static const CGFloat   kTabsH      = 36;
static const CGFloat   kFabSize    = 52;
static const int       kMaxBalance = 999999999;
static const int       kDefAmount  = 100000;
static const float     kSpeedMin   = 1.0f;
static const float     kSpeedMax   = 3.0f;

// ===== palette =====
static UIColor* Hex(uint32_t h, CGFloat a = 1) {
    return [UIColor colorWithRed:((h >> 16) & 0xFF) / 255.0
                           green:((h >> 8) & 0xFF) / 255.0
                            blue:(h & 0xFF) / 255.0
                           alpha:a];
}
#define C_ACCENT   Hex(0x8B5CF6)
#define C_ACCENT2  Hex(0xEC4899)
#define C_SOFT     Hex(0xA78BFA)
#define C_CARD     Hex(0x1C1C28)
#define C_CHIP     Hex(0x2A2A3C)
#define C_SUB      Hex(0x9CA3AF)
#define C_BODY     Hex(0xD1D5DB)
#define C_WARN     Hex(0xFBBF24)
#define C_TG       Hex(0x229ED9)
#define C_OK_BG    Hex(0x10B981, 0.22)
#define C_OK_FG    Hex(0x34D399)

// ===== localization =====
typedef NS_ENUM(NSInteger, SLang) { SLangRU = 0, SLangEN = 1, SLangAR = 2 };
static SLang gLang = SLangRU;
static BOOL RTL() { return gLang == SLangAR; }

static NSString* L(NSString* key) {
    static NSDictionary<NSString*, NSArray<NSString*>*>* t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = @{
            @"title":         @[@"XANTAPERS MOD", @"XANTAPERS MOD", @"XANTAPERS MOD"],
            @"tab_creators":  @[@"Creators", @"Creators", @"المطورون"],
            @"tab_hacks":     @[@"Hacks", @"Hacks", @"الغش"],
            @"settings":      @[@"Настройки", @"Settings", @"الإعدادات"],
            @"language":      @[@"Язык", @"Language", @"اللغة"],
            @"about_mod":     @[@"О моде", @"About", @"حول المود"],
            @"version":       @[@"Версия", @"Version", @"الإصدار"],
            @"made_by":       @[@"Сделано @xantapers", @"Made by @xantapers", @"صنع بواسطة @xantapers"],
            @"sec_currency":  @[@"Валюта", @"Currency", @"العملات"],
            @"sec_garage":    @[@"Гараж", @"Garage", @"الكراج"],
            @"sec_vehicle":   @[@"Машина", @"Vehicle", @"السيارة"],
            @"garage_hint":   @[@"Открой и поставь любую машину в гараж",
                                @"Unlock and equip any car in the garage",
                                @"افتح وضع أي سيارة في الكراج"],
            @"pick_car":      @[@"Выбрать любую машину", @"Pick any car", @"اختر أي سيارة"],
            @"unlock_current": @[@"Получить текущую в гараже",
                                 @"Get current garage car",
                                 @"الحصول على السيارة الحالية"],
            @"unlock_all_cars": @[@"Открыть все машины", @"Unlock all cars", @"فتح جميع السيارات"],
            @"unlocked_all_fmt": @[@"Открыто машин: {n} ✓",
                                   @"Unlocked {n} cars ✓",
                                   @"تم فتح {n} سيارة ✓"],
            @"search_car":    @[@"Поиск по названию или ID...",
                                @"Search by name or ID...",
                                @"ابحث بالاسم أو الرقم..."],
            @"back":          @[@"← Назад", @"← Back", @"رجوع →"],
            @"no_cars":       @[@"Машины не найдены", @"No cars found", @"لم يتم العثور على سيارات"],
            @"get_btn":       @[@"Взять", @"Get", @"احصل"],
            @"car_equipped_fmt": @[@"Получено: {name} ✓",
                                   @"Got: {name} ✓",
                                   @"تم الحصول على: {name} ✓"],
            @"gold":          @[@"Золото", @"Gold", @"ذهب"],
            @"silver":        @[@"Серебро", @"Silver", @"فضة"],
            @"keys":          @[@"Ключи", @"Keys", @"مفاتيح"],
            @"tickets":       @[@"Билеты", @"Tickets", @"تذاكر"],
            @"lapis":         @[@"Лазурит", @"Lapis Lazuli", @"لازورد"],
            @"xp":            @[@"Опыт", @"XP", @"خبرة"],
            @"balance_fmt":   @[@"Баланс: {v}", @"Balance: {v}", @"الرصيد: {v}"],
            @"cur_hint":      @[@"«+» добавить · «=» установить · MAX — максимум",
                                @"“+” add · “=” set · MAX — maximum",
                                @"«+» إضافة · «=» تعيين · MAX — الحد الأقصى"],
            @"max_all":       @[@"Максимум всей валюты", @"Max all currency", @"الحد الأقصى لكل العملات"],
            @"infinite":      @[@"Бесконечная валюта", @"Infinite currency", @"عملة لا نهائية"],
            @"infinite_hint": @[@"Пополняет баланс, когда он ниже 1 000 000",
                                @"Refills balance when it drops below 1,000,000",
                                @"يعيد تعبئة الرصيد عندما ينخفض تحت 1,000,000"],
            @"no_damage":     @[@"Без повреждений", @"No damage", @"بدون أضرار"],
            @"inf_fuel":      @[@"Бесконечное топливо", @"Infinite fuel", @"وقود لا نهائي"],
            @"no_heat":       @[@"Без перегрева", @"No overheating", @"بدون ارتفاع الحرارة"],
            @"max_grip":      @[@"Максимальное сцепление", @"Max grip", @"أقصى تماسك"],
            @"speed_boost":   @[@"Ускорение", @"Speed boost", @"تعزيز السرعة"],
            @"speed_hint":    @[@"Множитель макс. скорости и мощности",
                                @"Multiplies top speed and engine torque",
                                @"يضاعف السرعة القصوى وعزم المحرك"],
            @"speed_mult":    @[@"Множитель", @"Multiplier", @"المضاعف"],
            @"repair":        @[@"Починить машину", @"Repair vehicle", @"إصلاح السيارة"],
            @"amount":        @[@"Введите количество", @"Enter amount", @"أدخل الكمية"],
            @"add":           @[@"Добавить", @"Add", @"إضافة"],
            @"set":           @[@"Установить", @"Set", @"تعيين"],
            @"cancel":        @[@"Отмена", @"Cancel", @"إلغاء"],
            @"ok":            @[@"Готово ✓", @"Done ✓", @"تم ✓"],
            @"not_ready":     @[@"Игра ещё не загрузилась — зайди в главное меню",
                                @"Game not loaded yet — open the main menu",
                                @"اللعبة لم تُحمَّل بعد — افتح القائمة الرئيسية"],
            @"no_vehicle":    @[@"Сначала сядь в машину — включится автоматически",
                                @"Get in a vehicle — it applies automatically",
                                @"اركب سيارة أولاً — سيتم التفعيل تلقائياً"],
            @"creator_role":  @[@"Автор мода", @"Mod author", @"مطوّر المود"],
            @"creator_about": @[@"Telegram-канал @xantapers — моды и читы для iOS-игр без джейлбрейка и JIT. Готовые IPA, обновления под новые версии игр и анонсы новых модов.",
                                @"@xantapers on Telegram — mods and cheats for iOS games, no jailbreak or JIT needed. Ready-to-install IPAs, updates for new game versions and new mod announcements.",
                                @"قناة @xantapers على تيليجرام — مودات وغشّات لألعاب iOS بدون جيلبريك أو JIT. ملفات IPA جاهزة، تحديثات للإصدارات الجديدة وإعلانات المودات القادمة."],
            @"open_tg":       @[@"Открыть Telegram", @"Open Telegram", @"فتح تيليجرام"],
            @"subscribe":     @[@"Подписывайся — все обновления там", @"Subscribe — all updates are there", @"اشترك — كل التحديثات هناك"],
        };
    });
    NSArray<NSString*>* v = t[key];
    return v ? v[gLang] : key;
}

// ===== view helpers =====
static UILabel* Lbl(NSString* text, CGFloat size, UIFontWeight w, UIColor* color) {
    UILabel* l = [UILabel new];
    l.text = text;
    l.font = [UIFont systemFontOfSize:size weight:w];
    l.textColor = color;
    l.numberOfLines = 0;
    l.textAlignment = RTL() ? NSTextAlignmentRight : NSTextAlignmentLeft;
    return l;
}

static UIStackView* Stack(UILayoutConstraintAxis axis, CGFloat spacing) {
    UIStackView* s = [UIStackView new];
    s.axis = axis;
    s.spacing = spacing;
    s.alignment = axis == UILayoutConstraintAxisHorizontal ? UIStackViewAlignmentCenter : UIStackViewAlignmentFill;
    s.semanticContentAttribute = RTL() ? UISemanticContentAttributeForceRightToLeft
                                       : UISemanticContentAttributeForceLeftToRight;
    return s;
}

static void Size(UIView* v, CGFloat w, CGFloat h) {
    v.translatesAutoresizingMaskIntoConstraints = NO;
    if (w > 0) [v.widthAnchor constraintEqualToConstant:w].active = YES;
    if (h > 0) [v.heightAnchor constraintEqualToConstant:h].active = YES;
}

static CGFloat Clamp(CGFloat v, CGFloat lo, CGFloat hi) {
    return lo > hi ? (lo + hi) / 2 : MIN(MAX(v, lo), hi);
}

static UIWindow* KeyWindow() {
    UIApplication* app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene* s in app.connectedScenes) {
            if (![s isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow* w in ((UIWindowScene*)s).windows)
                if (w.isKeyWindow) return w;
        }
    }
    for (UIWindow* w in app.windows)
        if (w.isKeyWindow) return w;
    return app.windows.firstObject;
}

static CAGradientLayer* Gradient(CGRect frame, CGFloat radius) {
    CAGradientLayer* g = [CAGradientLayer layer];
    g.frame = frame;
    g.colors = @[(id)C_ACCENT.CGColor, (id)C_ACCENT2.CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    g.cornerRadius = radius;
    return g;
}

// ===== controls =====
@interface SBtn : UIButton
@property (nonatomic, copy) void (^onTap)(void);
+ (instancetype)title:(NSString*)title bg:(UIColor*)bg fg:(UIColor*)fg size:(CGFloat)size;
@end

@implementation SBtn
+ (instancetype)title:(NSString*)title bg:(UIColor*)bg fg:(UIColor*)fg size:(CGFloat)size {
    SBtn* b = [[SBtn alloc] initWithFrame:CGRectZero];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:fg forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.7;
    b.backgroundColor = bg;
    b.layer.cornerRadius = 10;
    [b addTarget:b action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
    [b addTarget:b action:@selector(down) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [b addTarget:b action:@selector(up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                                         UIControlEventTouchCancel | UIControlEventTouchDragExit];
    return b;
}
- (void)fire { if (self.onTap) self.onTap(); }
- (void)down {
    [UIView animateWithDuration:0.08 animations:^{
        self.alpha = 0.65;
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
    }];
}
- (void)up {
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }];
}
@end

@interface SSwitch : UISwitch
@property (nonatomic, assign) bool* ptr;
@property (nonatomic, copy) void (^onChange)(BOOL on);
@end

@implementation SSwitch
- (void)changed {
    if (self.ptr) *self.ptr = self.isOn;
    if (self.onChange) self.onChange(self.isOn);
}
@end

@interface SSlider : UISlider
@property (nonatomic, copy) void (^onChange)(float v);
@end

@implementation SSlider
- (void)changed { if (self.onChange) self.onChange(self.value); }
@end

// ===== menu =====
@interface SMenu : NSObject
+ (instancetype)shared;
- (void)attach;
@end

@implementation SMenu {
    UIWindow*      _win;
    UIView*        _fab;
    UIView*        _panel;
    UILabel*       _title;
    SBtn*          _gear;
    UIView*        _tabs;
    NSArray<SBtn*>* _tabBtns;
    UIScrollView*  _scroll;
    UIStackView*   _stack;
    NSInteger      _tab;        // 0 = Creators, 1 = Hacks
    BOOL           _settings;
    BOOL           _carPicker;
    BOOL           _dragging;
    int            _lastAmount;
    UILabel*       _speedLbl;
    UITextField*   _carSearch;
    UIStackView*   _carListStack;
    std::vector<secret::CarInfo> _carsCache;
    NSTimer*       _timer;
    NSMutableDictionary<NSNumber*, UILabel*>* _balance;
}

+ (instancetype)shared {
    static SMenu* m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [SMenu new]; });
    return m;
}

- (instancetype)init {
    if ((self = [super init])) {
        _tab = 1;
        _lastAmount = kDefAmount;
        _balance = [NSMutableDictionary new];
        NSUserDefaults* d = NSUserDefaults.standardUserDefaults;
        if ([d objectForKey:kLangKey]) {
            gLang = (SLang)MIN(MAX([d integerForKey:kLangKey], (NSInteger)0), (NSInteger)2);
        } else {
            NSString* p = NSLocale.preferredLanguages.firstObject ?: @"en";
            gLang = [p hasPrefix:@"ru"] ? SLangRU : [p hasPrefix:@"ar"] ? SLangAR : SLangEN;
        }
    }
    return self;
}

// ---------------------------------------------------------------- lifecycle
- (void)attach {
    UIWindow* w = KeyWindow();
    if (!w || w.bounds.size.width < 1) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self attach]; });
        return;
    }
    _win = w;
    [self buildFab];
    [self buildPanel];
    _timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)tick {
    UIWindow* w = KeyWindow();
    if (w && w != _win && w.bounds.size.width > 1) {
        _win = w;
        [w addSubview:_panel];
        [w addSubview:_fab];
    }
    if (!_win.rootViewController.presentedViewController) {
        [_win bringSubviewToFront:_panel];
        [_win bringSubviewToFront:_fab];
    }
    if (!_dragging) {
        [self clamp:_fab animated:NO];
        if (!_panel.hidden) [self clamp:_panel animated:NO];
    }
    if (!_panel.hidden && !_settings && !_carPicker && _tab == 1) [self refreshBalances];
}

// ---------------------------------------------------------------- floating button
- (void)buildFab {
    CGRect b = UIEdgeInsetsInsetRect(_win.bounds, _win.safeAreaInsets);
    UIView* f = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kFabSize, kFabSize)];
    f.center = CGPointMake(CGRectGetMaxX(b) - kFabSize, CGRectGetMinY(b) + b.size.height * 0.3);
    f.layer.shadowColor = C_ACCENT.CGColor;
    f.layer.shadowOpacity = 0.6;
    f.layer.shadowRadius = 12;
    f.layer.shadowOffset = CGSizeZero;
    [f.layer addSublayer:Gradient(f.bounds, kFabSize / 2)];

    UILabel* x = [[UILabel alloc] initWithFrame:f.bounds];
    x.text = @"X";
    x.textAlignment = NSTextAlignmentCenter;
    x.textColor = UIColor.whiteColor;
    x.font = [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy];
    [f addSubview:x];

    [f addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(show)]];
    [f addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    [_win addSubview:f];
    _fab = f;
}

// ---------------------------------------------------------------- panel shell
- (SBtn*)iconBtn:(NSString*)symbol alt:(NSString*)alt fallback:(NSString*)fallback {
    SBtn* b = [SBtn title:@"" bg:C_CHIP fg:UIColor.whiteColor size:15];
    b.layer.cornerRadius = 16;
    UIImage* img = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
        img = [UIImage systemImageNamed:symbol withConfiguration:cfg] ?: [UIImage systemImageNamed:alt withConfiguration:cfg];
    }
    if (img) {
        [b setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        b.tintColor = UIColor.whiteColor;
    } else {
        [b setTitle:fallback forState:UIControlStateNormal];
    }
    return b;
}

- (void)buildPanel {
    CGRect b = UIEdgeInsetsInsetRect(_win.bounds, _win.safeAreaInsets);
    CGFloat w = MIN(kPanelW, b.size.width - 16);
    CGFloat h = MIN(kPanelMaxH, b.size.height - 16);
    BOOL hidden = _panel ? _panel.hidden : YES;
    CGPoint c = _panel ? _panel.center : CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
    [_panel removeFromSuperview];

    UIView* p = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    p.center = c;
    p.hidden = hidden;
    p.layer.shadowColor = UIColor.blackColor.CGColor;
    p.layer.shadowOpacity = 0.55;
    p.layer.shadowRadius = 24;
    p.layer.shadowOffset = CGSizeMake(0, 10);

    UIView* clip = [[UIView alloc] initWithFrame:p.bounds];
    clip.layer.cornerRadius = 20;
    clip.layer.masksToBounds = YES;
    clip.layer.borderWidth = 1;
    clip.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    [p addSubview:clip];

    UIVisualEffectView* blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = clip.bounds;
    [clip addSubview:blur];
    UIView* tint = [[UIView alloc] initWithFrame:clip.bounds];
    tint.backgroundColor = Hex(0x0E0E16, 0.84);
    [clip addSubview:tint];

    // header: accent dot, title, gear + close on the right
    UIView* header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, kHeaderH)];
    [header addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    [clip addSubview:header];

    UIView* dot = [[UIView alloc] initWithFrame:CGRectMake(16, (kHeaderH - 10) / 2, 10, 10)];
    [dot.layer addSublayer:Gradient(dot.bounds, 5)];
    [header addSubview:dot];

    _title = [[UILabel alloc] initWithFrame:CGRectMake(34, 0, w - 34 - 96, kHeaderH)];
    _title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy];
    _title.textColor = UIColor.whiteColor;
    _title.adjustsFontSizeToFitWidth = YES;
    _title.minimumScaleFactor = 0.7;
    [header addSubview:_title];

    SBtn* close = [self iconBtn:@"xmark" alt:@"xmark" fallback:@"✕"];
    close.frame = CGRectMake(w - 12 - 32, (kHeaderH - 32) / 2, 32, 32);
    close.onTap = ^{ [self hide]; };
    [header addSubview:close];

    _gear = [self iconBtn:@"gearshape.fill" alt:@"gear" fallback:@"⚙\U0000FE0E"];
    _gear.frame = CGRectMake(w - 12 - 32 - 8 - 32, (kHeaderH - 32) / 2, 32, 32);
    _gear.onTap = ^{
        self->_settings = !self->_settings;
        if (self->_settings) self->_carPicker = NO;
        [self rebuildContent];
    };
    [header addSubview:_gear];

    UIView* line = [[UIView alloc] initWithFrame:CGRectMake(0, kHeaderH - 0.5, w, 0.5)];
    line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [header addSubview:line];

    // segmented tabs
    _tabs = [[UIView alloc] initWithFrame:CGRectMake(14, kHeaderH + 8, w - 28, kTabsH)];
    _tabs.backgroundColor = C_CARD;
    _tabs.layer.cornerRadius = 11;
    [clip addSubview:_tabs];

    NSArray<NSString*>* names = @[L(@"tab_creators"), L(@"tab_hacks")];
    NSMutableArray<SBtn*>* btns = [NSMutableArray array];
    CGFloat tw = (_tabs.bounds.size.width - 6) / 2;
    for (NSInteger i = 0; i < 2; i++) {
        SBtn* t = [SBtn title:names[i] bg:UIColor.clearColor fg:C_SUB size:14];
        t.layer.cornerRadius = 8;
        NSInteger slot = RTL() ? 1 - i : i;
        t.frame = CGRectMake(3 + slot * tw, 3, tw, kTabsH - 6);
        NSInteger idx = i;
        t.onTap = ^{
            self->_tab = idx;
            self->_settings = NO;
            self->_carPicker = NO;
            [self rebuildContent];
        };
        [_tabs addSubview:t];
        [btns addObject:t];
    }
    _tabBtns = btns;

    // scrollable content
    _scroll = [UIScrollView new];
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.alwaysBounceVertical = YES;
    _scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [clip addSubview:_scroll];

    _stack = Stack(UILayoutConstraintAxisVertical, 12);
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scroll addSubview:_stack];
    [NSLayoutConstraint activateConstraints:@[
        [_stack.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor constant:4],
        [_stack.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [_stack.leadingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.leadingAnchor constant:14],
        [_stack.trailingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.trailingAnchor constant:-14],
        [_stack.widthAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.widthAnchor constant:-28],
    ]];

    [_win addSubview:p];
    _panel = p;
    [self rebuildContent];
}

- (void)rebuildContent {
    for (UIView* v in _stack.arrangedSubviews) {
        [_stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [_balance removeAllObjects];
    _speedLbl = nil;
    _carSearch = nil;
    _carListStack = nil;

    CGFloat w = _panel.bounds.size.width, h = _panel.bounds.size.height;
    CGFloat top = (_settings || _carPicker) ? kHeaderH + 8 : kHeaderH + 8 + kTabsH + 12;
    _tabs.hidden = _settings || _carPicker;
    _scroll.frame = CGRectMake(0, top, w, h - top);
    _title.text = _settings ? L(@"settings") : (_carPicker ? L(@"pick_car") : L(@"title"));
    _gear.backgroundColor = _settings ? C_ACCENT : C_CHIP;

    for (NSInteger i = 0; i < (NSInteger)_tabBtns.count; i++) {
        SBtn* t = _tabBtns[i];
        BOOL sel = i == _tab;
        t.backgroundColor = sel ? C_ACCENT : UIColor.clearColor;
        [t setTitleColor:sel ? UIColor.whiteColor : C_SUB forState:UIControlStateNormal];
    }

    if (_settings)       [self buildSettings];
    else if (_carPicker) [self buildCarPicker];
    else if (_tab == 0)  [self buildCreators];
    else                 [self buildHacks];

    _scroll.contentOffset = CGPointZero;
    if (!_settings && !_carPicker && _tab == 1) [self refreshBalances];
}

// ---------------------------------------------------------------- building blocks
- (UIStackView*)card:(NSString*)title {
    UIView* card = [UIView new];
    card.backgroundColor = C_CARD;
    card.layer.cornerRadius = 14;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.05].CGColor;

    UIStackView* s = Stack(UILayoutConstraintAxisVertical, 10);
    s.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:s];
    [NSLayoutConstraint activateConstraints:@[
        [s.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [s.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
        [s.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [s.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
    ]];
    if (title.length) [s addArrangedSubview:Lbl(title.uppercaseString, 12, UIFontWeightBold, C_SOFT)];
    [_stack addArrangedSubview:card];
    return s;
}

- (SBtn*)primary:(NSString*)title bg:(UIColor*)bg {
    SBtn* b = [SBtn title:title bg:bg fg:UIColor.whiteColor size:15];
    b.layer.cornerRadius = 12;
    Size(b, 0, 44);
    return b;
}

- (SSwitch*)toggle:(UIStackView*)s title:(NSString*)title hint:(NSString*)hint value:(bool*)ptr {
    UIStackView* row = Stack(UILayoutConstraintAxisHorizontal, 10);
    UIStackView* txt = Stack(UILayoutConstraintAxisVertical, 2);
    [txt addArrangedSubview:Lbl(title, 15, UIFontWeightMedium, UIColor.whiteColor)];
    if (hint.length) [txt addArrangedSubview:Lbl(hint, 11, UIFontWeightRegular, C_SUB)];
    [row addArrangedSubview:txt];

    SSwitch* sw = [SSwitch new];
    sw.on = *ptr;
    sw.ptr = ptr;
    sw.onTintColor = C_ACCENT;
    [sw addTarget:sw action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    [sw setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [sw setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:sw];
    [s addArrangedSubview:row];
    return sw;
}

- (NSString*)currencyName:(secret::Currency)c {
    static NSString* const keys[] = { @"gold", @"silver", @"keys", @"tickets", @"lapis", @"xp" };
    return L(keys[(int)c]);
}

- (void)currencyRow:(UIStackView*)s cur:(secret::Currency)c {
    UIStackView* row = Stack(UILayoutConstraintAxisHorizontal, 6);

    UIStackView* txt = Stack(UILayoutConstraintAxisVertical, 1);
    UILabel* name = Lbl([self currencyName:c], 15, UIFontWeightSemibold, UIColor.whiteColor);
    UILabel* bal = Lbl(@"—", 11, UIFontWeightRegular, C_SUB);
    bal.numberOfLines = 1;
    bal.adjustsFontSizeToFitWidth = YES;
    bal.minimumScaleFactor = 0.7;
    [txt addArrangedSubview:name];
    [txt addArrangedSubview:bal];
    [txt setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:txt];
    _balance[@((int)c)] = bal;

    SBtn* add = [SBtn title:@"+" bg:C_CHIP fg:UIColor.whiteColor size:18];
    Size(add, 40, 34);
    add.onTap = ^{ [self prompt:c set:NO]; };

    SBtn* set = [SBtn title:@"=" bg:C_CHIP fg:UIColor.whiteColor size:18];
    Size(set, 40, 34);
    set.onTap = ^{ [self prompt:c set:YES]; };

    SBtn* max = [SBtn title:@"MAX" bg:[C_ACCENT colorWithAlphaComponent:0.25] fg:C_SOFT size:12];
    Size(max, 50, 34);
    max.onTap = ^{
        [self toast:secret::setBalance(c, kMaxBalance) ? L(@"ok") : L(@"not_ready")];
        [self refreshBalances];
    };

    [row addArrangedSubview:add];
    [row addArrangedSubview:set];
    [row addArrangedSubview:max];
    [s addArrangedSubview:row];
}

// ---------------------------------------------------------------- tabs
- (void)buildHacks {
    if (!secret::ready()) {
        UIStackView* warn = [self card:nil];
        [warn addArrangedSubview:Lbl(L(@"not_ready"), 13, UIFontWeightMedium, C_WARN)];
    }

    // currency
    UIStackView* cur = [self card:L(@"sec_currency")];
    [cur addArrangedSubview:Lbl(L(@"cur_hint"), 11, UIFontWeightRegular, C_SUB)];
    static const secret::Currency order[] = {
        secret::kGold, secret::kSilver, secret::kKeys, secret::kTickets, secret::kLapis, secret::kXP
    };
    for (secret::Currency c : order) [self currencyRow:cur cur:c];

    SBtn* maxAll = [self primary:L(@"max_all") bg:C_ACCENT];
    maxAll.onTap = ^{
        bool ok = true;
        for (secret::Currency c : order)
            if (c != secret::kXP) ok = secret::setBalance(c, kMaxBalance) && ok;
        [self toast:ok ? L(@"ok") : L(@"not_ready")];
        [self refreshBalances];
    };
    [cur addArrangedSubview:maxAll];
    [self toggle:cur title:L(@"infinite") hint:L(@"infinite_hint") value:&secret::state().infiniteCurrency];

    // garage
    UIStackView* gar = [self card:L(@"sec_garage")];
    [gar addArrangedSubview:Lbl(L(@"garage_hint"), 11, UIFontWeightRegular, C_SUB)];

    SBtn* pickCar = [self primary:L(@"pick_car") bg:C_ACCENT];
    pickCar.onTap = ^{
        self->_carsCache = secret::listCars();
        if (self->_carsCache.empty()) {
            [self toast:L(@"not_ready")];
            return;
        }
        self->_carPicker = YES;
        [self rebuildContent];
    };
    [gar addArrangedSubview:pickCar];

    SBtn* unlockCur = [self primary:L(@"unlock_current") bg:C_CHIP];
    unlockCur.onTap = ^{
        std::string name;
        if (!secret::unlockCurrentCar(&name)) {
            [self toast:L(@"not_ready")];
            return;
        }
        NSString* nm = [NSString stringWithUTF8String:name.c_str()] ?: @"";
        [self toast:[L(@"car_equipped_fmt") stringByReplacingOccurrencesOfString:@"{name}" withString:nm]];
    };
    [gar addArrangedSubview:unlockCur];

    SBtn* unlockAll = [self primary:L(@"unlock_all_cars") bg:C_CHIP];
    unlockAll.onTap = ^{
        int n = secret::unlockAllCars();
        if (n < 0) {
            [self toast:L(@"not_ready")];
            return;
        }
        [self toast:[L(@"unlocked_all_fmt") stringByReplacingOccurrencesOfString:@"{n}"
                                                                      withString:[NSString stringWithFormat:@"%d", n]]];
    };
    [gar addArrangedSubview:unlockAll];

    // vehicle
    secret::State& st = secret::state();
    UIStackView* veh = [self card:L(@"sec_vehicle")];
    void (^needCar)(BOOL) = ^(BOOL on) {
        if (on && !secret::hasVehicle()) [self toast:L(@"no_vehicle")];
    };
    [self toggle:veh title:L(@"no_damage") hint:nil value:&st.noDamage].onChange = needCar;
    [self toggle:veh title:L(@"inf_fuel")  hint:nil value:&st.infFuel].onChange  = needCar;
    [self toggle:veh title:L(@"no_heat")   hint:nil value:&st.noHeat].onChange   = needCar;
    [self toggle:veh title:L(@"max_grip")  hint:nil value:&st.maxGrip].onChange  = needCar;
    [self toggle:veh title:L(@"speed_boost") hint:L(@"speed_hint") value:&st.speedBoost].onChange = needCar;

    UIStackView* sr = Stack(UILayoutConstraintAxisHorizontal, 10);
    _speedLbl = Lbl([NSString stringWithFormat:@"%@ ×%.1f", L(@"speed_mult"), st.speedMult], 13, UIFontWeightSemibold, C_BODY);
    _speedLbl.numberOfLines = 1;
    _speedLbl.adjustsFontSizeToFitWidth = YES;
    Size(_speedLbl, 116, 0);
    SSlider* sl = [SSlider new];
    sl.minimumValue = kSpeedMin;
    sl.maximumValue = kSpeedMax;
    sl.value = st.speedMult;
    sl.minimumTrackTintColor = C_ACCENT;
    sl.semanticContentAttribute = sr.semanticContentAttribute;
    [sl addTarget:sl action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    sl.onChange = ^(float v) {
        secret::state().speedMult = roundf(v * 10.f) / 10.f;
        self->_speedLbl.text = [NSString stringWithFormat:@"%@ ×%.1f", L(@"speed_mult"), secret::state().speedMult];
    };
    [sr addArrangedSubview:_speedLbl];
    [sr addArrangedSubview:sl];
    [veh addArrangedSubview:sr];

    SBtn* repair = [self primary:L(@"repair") bg:C_CHIP];
    repair.onTap = ^{ [self toast:secret::repairVehicle() ? L(@"ok") : L(@"no_vehicle")]; };
    [veh addArrangedSubview:repair];
}

- (void)buildCarPicker {
    UIStackView* top = Stack(UILayoutConstraintAxisHorizontal, 10);
    SBtn* back = [SBtn title:L(@"back") bg:C_CHIP fg:UIColor.whiteColor size:13];
    back.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    Size(back, 0, 34);
    [back setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    back.onTap = ^{
        [self->_win endEditing:YES];
        self->_carPicker = NO;
        [self rebuildContent];
    };
    UILabel* countLbl = Lbl(@(_carsCache.size()).stringValue, 13, UIFontWeightSemibold, C_SUB);
    countLbl.textAlignment = RTL() ? NSTextAlignmentLeft : NSTextAlignmentRight;
    [countLbl setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [top addArrangedSubview:back];
    [top addArrangedSubview:countLbl];
    [_stack addArrangedSubview:top];

    UITextField* sf = [UITextField new];
    sf.backgroundColor = C_CARD;
    sf.layer.cornerRadius = 10;
    sf.layer.borderWidth = 1;
    sf.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    sf.textColor = UIColor.whiteColor;
    sf.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    sf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:L(@"search_car")
                                                               attributes:@{ NSForegroundColorAttributeName: C_SUB }];
    sf.clearButtonMode = UITextFieldViewModeWhileEditing;
    sf.autocorrectionType = UITextAutocorrectionTypeNo;
    sf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    sf.returnKeyType = UIReturnKeySearch;
    sf.textAlignment = RTL() ? NSTextAlignmentRight : NSTextAlignmentLeft;
    UIView* pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    if (RTL()) {
        sf.rightView = pad;
        sf.rightViewMode = UITextFieldViewModeAlways;
    } else {
        sf.leftView = pad;
        sf.leftViewMode = UITextFieldViewModeAlways;
    }
    Size(sf, 0, 38);
    [sf addTarget:self action:@selector(carSearchChanged:) forControlEvents:UIControlEventEditingChanged];
    [sf addTarget:sf action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
    [_stack addArrangedSubview:sf];
    _carSearch = sf;

    _carListStack = Stack(UILayoutConstraintAxisVertical, 8);
    [_stack addArrangedSubview:_carListStack];
    [self reloadCarRows];
}

- (void)carSearchChanged:(UITextField*)sender {
    (void)sender;
    [self reloadCarRows];
}

- (void)reloadCarRows {
    if (!_carListStack) return;
    for (UIView* v in _carListStack.arrangedSubviews) {
        [_carListStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    NSString* q = [_carSearch.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    static NSString* const kClasses[] = { @"", @"D", @"C", @"B", @"A", @"S" };

    NSInteger shown = 0;
    for (size_t i = 0; i < _carsCache.size(); ++i) {
        const secret::CarInfo& car = _carsCache[i];
        NSString* name = [NSString stringWithUTF8String:car.name.c_str()] ?: [NSString stringWithFormat:@"Car #%d", car.id];
        NSString* idStr = [NSString stringWithFormat:@"%d", car.id];
        if (q.length > 0 &&
            [name rangeOfString:q options:NSCaseInsensitiveSearch].location == NSNotFound &&
            [idStr rangeOfString:q options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }
        ++shown;

        UIView* rowCard = [UIView new];
        rowCard.backgroundColor = C_CARD;
        rowCard.layer.cornerRadius = 12;
        rowCard.layer.borderWidth = 1;
        rowCard.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.05].CGColor;

        UIStackView* row = Stack(UILayoutConstraintAxisHorizontal, 10);
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [rowCard addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.topAnchor constraintEqualToAnchor:rowCard.topAnchor constant:10],
            [row.bottomAnchor constraintEqualToAnchor:rowCard.bottomAnchor constant:-10],
            [row.leadingAnchor constraintEqualToAnchor:rowCard.leadingAnchor constant:10],
            [row.trailingAnchor constraintEqualToAnchor:rowCard.trailingAnchor constant:-10],
        ]];

        UIStackView* txt = Stack(UILayoutConstraintAxisVertical, 2);
        UILabel* title = Lbl(name, 14, UIFontWeightSemibold, UIColor.whiteColor);
        NSMutableString* sub = [NSMutableString stringWithFormat:@"#%d", car.id];
        if (car.carClass >= 1 && car.carClass <= 5) [sub appendFormat:@" · Class %@", kClasses[car.carClass]];
        if (car.pp > 0) [sub appendFormat:@" · PP %d", car.pp];
        UILabel* subLbl = Lbl(sub, 11, UIFontWeightRegular, C_SUB);
        [txt addArrangedSubview:title];
        [txt addArrangedSubview:subLbl];
        [txt setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [row addArrangedSubview:txt];

        SBtn* btn = [SBtn title:(car.owned ? @"✓" : L(@"get_btn"))
                             bg:(car.owned ? C_OK_BG : C_ACCENT)
                             fg:(car.owned ? C_OK_FG : UIColor.whiteColor)
                           size:13];
        Size(btn, 64, 34);
        __weak SBtn* wbtn = btn;
        size_t cacheIdx = i;
        int carId = car.id;
        btn.onTap = ^{
            std::string eqName;
            if (!secret::unlockAndEquipCar(carId, &eqName)) {
                [self toast:L(@"not_ready")];
                return;
            }
            if (cacheIdx < self->_carsCache.size() && self->_carsCache[cacheIdx].id == carId)
                self->_carsCache[cacheIdx].owned = true;
            SBtn* b = wbtn;
            if (b) {
                [b setTitle:@"✓" forState:UIControlStateNormal];
                [b setTitleColor:C_OK_FG forState:UIControlStateNormal];
                b.backgroundColor = C_OK_BG;
            }
            NSString* nm = [NSString stringWithUTF8String:eqName.c_str()] ?: @"";
            [self toast:[L(@"car_equipped_fmt") stringByReplacingOccurrencesOfString:@"{name}" withString:nm]];
        };
        [row addArrangedSubview:btn];
        [_carListStack addArrangedSubview:rowCard];
    }

    if (shown == 0) {
        UILabel* empty = Lbl(L(@"no_cars"), 13, UIFontWeightMedium, C_SUB);
        empty.textAlignment = NSTextAlignmentCenter;
        [_carListStack addArrangedSubview:empty];
    }
}

- (void)buildCreators {
    UIStackView* c = [self card:nil];

    UIStackView* top = Stack(UILayoutConstraintAxisHorizontal, 14);
    UIView* av = [UIView new];
    Size(av, 64, 64);
    [av.layer addSublayer:Gradient(CGRectMake(0, 0, 64, 64), 32)];
    UILabel* x = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
    x.text = @"X";
    x.textAlignment = NSTextAlignmentCenter;
    x.textColor = UIColor.whiteColor;
    x.font = [UIFont systemFontOfSize:30 weight:UIFontWeightHeavy];
    [av addSubview:x];

    UIStackView* names = Stack(UILayoutConstraintAxisVertical, 3);
    [names addArrangedSubview:Lbl([@"@" stringByAppendingString:kTgHandle], 20, UIFontWeightBold, UIColor.whiteColor)];
    [names addArrangedSubview:Lbl(L(@"creator_role"), 13, UIFontWeightMedium, C_SOFT)];
    [top addArrangedSubview:av];
    [top addArrangedSubview:names];
    [c addArrangedSubview:top];

    [c addArrangedSubview:Lbl(L(@"creator_about"), 14, UIFontWeightRegular, C_BODY)];

    SBtn* tg = [self primary:[NSString stringWithFormat:@"✈\U0000FE0E  %@", L(@"open_tg")] bg:C_TG];
    tg.onTap = ^{ [self openTelegram]; };
    [c addArrangedSubview:tg];

    UILabel* sub = Lbl(L(@"subscribe"), 12, UIFontWeightRegular, C_SUB);
    sub.textAlignment = NSTextAlignmentCenter;
    [c addArrangedSubview:sub];

    UIStackView* about = [self card:L(@"about_mod")];
    [about addArrangedSubview:Lbl([NSString stringWithFormat:@"%@ %@", L(@"version"), kModVersion], 14, UIFontWeightMedium, UIColor.whiteColor)];
    [about addArrangedSubview:Lbl(L(@"made_by"), 13, UIFontWeightRegular, C_SUB)];
}

- (void)buildSettings {
    UIStackView* lang = [self card:L(@"language")];
    UISegmentedControl* seg = [[UISegmentedControl alloc] initWithItems:@[@"Русский", @"English", @"العربية"]];
    seg.selectedSegmentIndex = gLang;
    if (@available(iOS 13.0, *)) seg.selectedSegmentTintColor = C_ACCENT;
    seg.backgroundColor = C_CHIP;
    NSDictionary* attrs = @{ NSForegroundColorAttributeName: UIColor.whiteColor,
                             NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold] };
    [seg setTitleTextAttributes:attrs forState:UIControlStateNormal];
    [seg setTitleTextAttributes:attrs forState:UIControlStateSelected];
    [seg addTarget:self action:@selector(langChanged:) forControlEvents:UIControlEventValueChanged];
    Size(seg, 0, 36);
    [lang addArrangedSubview:seg];

    UIStackView* about = [self card:L(@"about_mod")];
    [about addArrangedSubview:Lbl([NSString stringWithFormat:@"%@ %@", L(@"version"), kModVersion], 14, UIFontWeightMedium, UIColor.whiteColor)];
    [about addArrangedSubview:Lbl(L(@"made_by"), 13, UIFontWeightRegular, C_SUB)];
}

// ---------------------------------------------------------------- actions
- (void)langChanged:(UISegmentedControl*)seg {
    gLang = (SLang)seg.selectedSegmentIndex;
    [NSUserDefaults.standardUserDefaults setInteger:gLang forKey:kLangKey];
    [self buildPanel];   // full rebuild: titles, tabs, RTL order
}

- (void)prompt:(secret::Currency)c set:(BOOL)isSet {
    NSString* title = [NSString stringWithFormat:@"%@ — %@", [self currencyName:c], isSet ? L(@"set") : L(@"add")];
    UIAlertController* a = [UIAlertController alertControllerWithTitle:title
                                                               message:L(@"amount")
                                                        preferredStyle:UIAlertControllerStyleAlert];
    int last = _lastAmount;
    [a addTextFieldWithConfigurationHandler:^(UITextField* f) {
        f.keyboardType = UIKeyboardTypeNumberPad;
        f.text = [NSString stringWithFormat:@"%d", last];
        f.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [a addAction:[UIAlertAction actionWithTitle:L(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak UIAlertController* wa = a;
    [a addAction:[UIAlertAction actionWithTitle:isSet ? L(@"set") : L(@"add") style:UIAlertActionStyleDefault handler:^(UIAlertAction*) {
        long long v = wa.textFields.firstObject.text.longLongValue;
        if (v < 0 || (!isSet && v == 0)) return;
        if (v > kMaxBalance) v = kMaxBalance;
        if (v > 0) self->_lastAmount = (int)v;
        bool ok = isSet ? secret::setBalance(c, (int)v) : secret::addBalance(c, (int)v);
        [self toast:ok ? L(@"ok") : L(@"not_ready")];
        [self refreshBalances];
    }]];

    UIViewController* top = _win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:a animated:YES completion:nil];
}

- (void)refreshBalances {
    if (!_balance.count) return;
    static NSNumberFormatter* nf;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        nf = [NSNumberFormatter new];
        nf.numberStyle = NSNumberFormatterDecimalStyle;
        nf.groupingSeparator = @" ";
        nf.usesGroupingSeparator = YES;
    });
    NSString* fmt = L(@"balance_fmt");
    [_balance enumerateKeysAndObjectsUsingBlock:^(NSNumber* k, UILabel* l, BOOL*) {
        int v = secret::getBalance((secret::Currency)k.intValue);
        l.text = v < 0 ? @"—" : [fmt stringByReplacingOccurrencesOfString:@"{v}" withString:[nf stringFromNumber:@(v)]];
    }];
}

- (void)openTelegram {
    NSURL* app = [NSURL URLWithString:[@"tg://resolve?domain=" stringByAppendingString:kTgHandle]];
    NSURL* web = [NSURL URLWithString:[@"https://t.me/" stringByAppendingString:kTgHandle]];
    [UIApplication.sharedApplication openURL:app options:@{} completionHandler:^(BOOL ok) {
        if (!ok) [UIApplication.sharedApplication openURL:web options:@{} completionHandler:nil];
    }];
}

- (void)toast:(NSString*)msg {
    UILabel* t = [UILabel new];
    t.text = msg;
    t.numberOfLines = 0;
    t.textAlignment = NSTextAlignmentCenter;
    t.textColor = UIColor.whiteColor;
    t.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    t.backgroundColor = Hex(0x1F1F2E, 0.96);
    t.layer.cornerRadius = 12;
    t.layer.masksToBounds = YES;
    t.layer.borderWidth = 1;
    t.layer.borderColor = [C_ACCENT colorWithAlphaComponent:0.4].CGColor;

    CGSize sz = [t sizeThatFits:CGSizeMake(_win.bounds.size.width - 80, CGFLOAT_MAX)];
    t.frame = CGRectMake(0, 0, sz.width + 32, sz.height + 18);
    t.center = CGPointMake(CGRectGetMidX(_win.bounds),
                           CGRectGetMaxY(_win.bounds) - _win.safeAreaInsets.bottom - 44);
    t.alpha = 0;
    [_win addSubview:t];
    [UIView animateWithDuration:0.2 animations:^{ t.alpha = 1; } completion:^(BOOL) {
        [UIView animateWithDuration:0.3 delay:1.6 options:0 animations:^{ t.alpha = 0; }
                         completion:^(BOOL) { [t removeFromSuperview]; }];
    }];
}

// ---------------------------------------------------------------- show / hide / drag
- (void)show {
    [self clamp:_panel animated:NO];
    _panel.hidden = NO;
    _panel.alpha = 0;
    _panel.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:0 animations:^{
        self->_panel.alpha = 1;
        self->_panel.transform = CGAffineTransformIdentity;
        self->_fab.alpha = 0;
    } completion:^(BOOL) { self->_fab.hidden = YES; }];
    if (!_settings && !_carPicker && _tab == 1) [self refreshBalances];
}

- (void)hide {
    [_win endEditing:YES];
    _fab.hidden = NO;
    [UIView animateWithDuration:0.18 animations:^{
        self->_panel.alpha = 0;
        self->_panel.transform = CGAffineTransformMakeScale(0.92, 0.92);
        self->_fab.alpha = 1;
    } completion:^(BOOL) {
        self->_panel.hidden = YES;
        self->_panel.transform = CGAffineTransformIdentity;
    }];
}

- (void)drag:(UIPanGestureRecognizer*)g {
    UIView* v = g.view == _fab ? _fab : _panel;
    CGPoint t = [g translationInView:_win];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:_win];
    _dragging = g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged;
    if (!_dragging) [self clamp:v animated:YES];
}

- (void)clamp:(UIView*)v animated:(BOOL)animated {
    if (!v || !_win) return;
    CGRect b = UIEdgeInsetsInsetRect(_win.bounds, _win.safeAreaInsets);
    CGSize s = v.bounds.size;
    CGPoint c = CGPointMake(Clamp(v.center.x, CGRectGetMinX(b) + s.width / 2, CGRectGetMaxX(b) - s.width / 2),
                            Clamp(v.center.y, CGRectGetMinY(b) + s.height / 2, CGRectGetMaxY(b) - s.height / 2));
    if (CGPointEqualToPoint(c, v.center)) return;
    if (animated) [UIView animateWithDuration:0.2 animations:^{ v.center = c; }];
    else          v.center = c;
}

@end

extern "C" void SecretMenuInit(void) {
    [[SMenu shared] attach];
}
