#import <Foundation/Foundation.h>
#import "ExperimentalViewController.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface ExperimentalViewController ()
@end

@implementation ExperimentalViewController

- (id)init {
    self = [super init];
    self.title = localize(@"launcher.menu.experimental", @"Experimental");
    return self;
}

- (NSString *)imageName {
    return @"flask";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.getPreference = ^id(NSString *section, NSString *key) {
        NSString *fullKey = [NSString stringWithFormat:@"experimental.%@", key];
        return getPrefObject(fullKey);
    };

    self.setPreference = ^(NSString *section, NSString *key, id value) {
        NSString *fullKey = [NSString stringWithFormat:@"experimental.%@", key];
        setPrefObject(fullKey, value);
    };

    self.hasDetail = YES;
    self.prefDetailVisible = YES;

    self.prefSections = @[@"diagnostics", @"renderer_opt", @"runtime_exp", @"reset"];

    __weak typeof(self) weakSelf = self;
    void(^resetAction)(void) = ^{
        setPrefBool(@"experimental.benchmark", NO);
        setPrefBool(@"experimental.fps_log", NO);
        setPrefBool(@"experimental.shader_error_log", NO);
        setPrefObject(@"experimental.draw_batching", @"default");
        setPrefObject(@"experimental.use_vbo", @"default");
        setPrefObject(@"experimental.mipmap_mode", @"default");
        setPrefBool(@"experimental.no_shader_lod", NO);
        setPrefObject(@"experimental.shrink_texture", @"default");
        setPrefBool(@"experimental.no_vao_cache", NO);
        setPrefBool(@"experimental.low_stutter_jvm", NO);
        setPrefObject(@"experimental.adaptive_render_scale", @"unsupported");
        [weakSelf.tableView reloadData];
    };

    self.prefContents = @[
        @[
            // Diagnostics & Metrics
            @{@"icon": @"waveform.path.ecg"},
            @{
                @"key": @"benchmark",
                @"hasDetail": @YES,
                @"icon": @"speedometer",
                @"type": self.typeSwitch
            },
            @{
                @"key": @"fps_log",
                @"hasDetail": @YES,
                @"icon": @"chart.bar.xaxis",
                @"type": self.typeSwitch
            },
            @{
                @"key": @"shader_error_log",
                @"hasDetail": @YES,
                @"icon": @"exclamationmark.bubble",
                @"type": self.typeSwitch
            }
        ],
        @[
            // Renderer Optimizations (GL4ES)
            @{@"icon": @"cpu"},
            @{
                @"key": @"draw_batching",
                @"hasDetail": @YES,
                @"icon": @"square.stack.3d.up",
                @"type": self.typePickField,
                @"pickKeys": @[@"default", @"off", @"1", @"10", @"100"],
                @"pickList": @[@"Default", @"Off (0)", @"Low (100)", @"Medium (1,000)", @"High (10,000)"]
            },
            @{
                @"key": @"use_vbo",
                @"hasDetail": @YES,
                @"icon": @"memorychip",
                @"type": self.typePickField,
                @"pickKeys": @[@"default", @"0", @"1", @"2"],
                @"pickList": @[@"Default", @"0 - Disabled", @"1 - Standard VBO", @"2 - VBO + glLockArrays"]
            },
            @{
                @"key": @"mipmap_mode",
                @"hasDetail": @YES,
                @"icon": @"photo.stack",
                @"type": self.typePickField,
                @"pickKeys": @[@"default", @"1", @"2", @"3", @"4"],
                @"pickList": @[@"Default", @"1 - Force AutoMipMap", @"2 - Guess AutoMipMap", @"3 - Disable MipMaps", @"4 - Non-Square Ignored"]
            },
            @{
                @"key": @"no_shader_lod",
                @"hasDetail": @YES,
                @"icon": @"camera.filters",
                @"type": self.typeSwitch
            },
            @{
                @"key": @"shrink_texture",
                @"hasDetail": @YES,
                @"icon": @"arrow.down.right.and.arrow.up.left",
                @"type": self.typePickField,
                @"pickKeys": @[@"default", @"1", @"2", @"3", @"7"],
                @"pickList": @[@"Default (No Shrink)", @"1 - Half All Textures (/2)", @"2 - Half Textures >512 (/2)", @"3 - Half Textures >256 (/2)", @"7 - Half >512 (Keep Empty)"]
            },
            @{
                @"key": @"no_vao_cache",
                @"hasDetail": @YES,
                @"icon": @"internaldrive",
                @"type": self.typeSwitch
            }
        ],
        @[
            // Engine & Runtime
            @{@"icon": @"gearshape.2"},
            @{
                @"key": @"low_stutter_jvm",
                @"hasDetail": @YES,
                @"icon": @"bolt.badge.clock",
                @"type": self.typeSwitch
            },
            @{
                @"key": @"adaptive_render_scale",
                @"hasDetail": @YES,
                @"icon": @"viewfinder",
                @"type": self.typePickField,
                @"pickKeys": @[@"unsupported"],
                @"pickList": @[@"Deferred (Under Research)"]
            }
        ],
        @[
            // Reset to Safe Defaults
            @{@"icon": @"arrow.counterclockwise"},
            @{
                @"key": @"reset_defaults",
                @"hasDetail": @YES,
                @"icon": @"arrow.counterclockwise.circle",
                @"type": self.typeButton,
                @"destructive": @YES,
                @"showConfirmPrompt": @YES,
                @"action": resetAction
            }
        ]
    ];
}

@end
