import 'package:demo/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:clipboard/clipboard.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:android_intent/android_intent.dart';
import 'package:http/http.dart' as http;
import 'package:package_info/package_info.dart';
import 'package:lottie/lottie.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class AnimatedSplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const AnimatedSplashScreen({super.key, required this.nextScreen});

  @override
  // ignore: library_private_types_in_public_api
  _AnimatedSplashScreenState createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  @override
  void initState() {
    super.initState();
    _startAnimationAndNavigate();
  }

  void _startAnimationAndNavigate() async {
    await Future.delayed(
        const Duration(seconds: 2)); // Assuming 5 seconds animation
    if (mounted) {
      // Check if the widget is still in the widget tree
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset('assests/animation/animation1.json'),
      ),
    );
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    });
  }

  MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    strengths.forEach((strength) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    });
    return MaterialColor(color.value, swatch);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Package Finder',
      theme: ThemeData(
          primarySwatch: createMaterialColor(Color.fromRGBO(49, 14, 75, 1))),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: AnimatedSplashScreen(
          nextScreen: InstalledAppsList(toggleTheme: _toggleTheme)),
    );
  }
}

class InstalledAppsList extends StatefulWidget {
  final VoidCallback toggleTheme;

  const InstalledAppsList({Key? key, required this.toggleTheme})
      : super(key: key);

  @override
  InstalledAppsListState createState() => InstalledAppsListState();
}

class InstalledAppsListState extends State<InstalledAppsList> {
  final List<Application> _apps = [];
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedPackages = {};
  BannerAd? _bannerAd;
  bool _loading = false;
  RewardedAd? _rewardedAd;
  bool _isRewardAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkForNewVersion(context);
    _fetchInstalledApps();
    _loadBannerAd();
    _loadRewardedAd();
  }

  void _checkForNewVersion(BuildContext context) async {
    final isNewVersion = await isNewVersionAvailable();
    if (isNewVersion) {
      _showUpdateDialog();
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Available"),
        content: const Text("A new version is available on the Play Store."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Later"),
          ),
          TextButton(
            onPressed: () {
              const intent = AndroidIntent(
                action: 'action_view',
                data:
                    'https://play.google.com/store/apps/details?id=com.kwikittlabs.packagefinderanduninstaller',
              );
              intent.launch();
              Navigator.of(context).pop();
            },
            child: const Text("Update Now"),
          )
        ],
      ),
    );
  }

  Future<bool> isNewVersionAvailable() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final currentVersion = info.version.trim();

    final response = await http.get(Uri.parse(
        'https://play.google.com/store/apps/details?id=${info.packageName}&hl=en'));

    if (response.statusCode == 200) {
      final regex =
          RegExp(r'(?<=Current Version</div><span class="htlgb">)[^<]*');
      final match = regex.firstMatch(response.body);
      if (match != null) {
        final versionOnPlayStore = match.group(0)?.trim() ?? '';
        if (versionOnPlayStore != currentVersion) {
          return true;
        }
      }
    }
    return false;
  }

  void _loadBannerAd() {
    BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _bannerAd = ad as BannerAd),
        onAdFailedToLoad: (ad, err) {
          print('Failed to load a banner ad: ${err.message}');
          ad.dispose();
        },
      ),
    ).load();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId, // replace with your AdUnit ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardAdLoaded = true;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedAd failed to load: ${error.message}');
          setState(() {
            _isRewardAdLoaded = false;
          });
        },
      ),
    );
  }

  void _fetchInstalledApps() async {
    if (_loading) return;

    setState(() => _loading = true);
    List<Application> allApps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: false,
    );

    setState(() {
      _apps.clear();
      _apps.addAll(allApps);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Finder & Uninstaller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: AppSearchDelegate(_apps, _selectedPackages),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: _buildAppList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _uninstallSelectedApps,
        child: const Icon(Icons.delete),
      ),
      bottomNavigationBar: _bannerAd == null
          ? null
          : Container(
              alignment: Alignment.center,
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            ),
    );
  }

  Widget _buildAppList() {
    if (_loading && _apps.isEmpty) {
      // If it's the first time loading and apps list is empty
      return ListView.builder(
        physics: const ClampingScrollPhysics(),
        itemCount: 10, // Show 10 loading indicators as placeholders
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
              ),
              title: Container(
                margin: const EdgeInsets.only(top: 5.0),
                height: 20.0,
                width: MediaQuery.of(context).size.width *
                    0.6, // 60% of screen width
                color: Colors.grey.shade200,
              ),
              subtitle: Container(
                margin: const EdgeInsets.only(top: 8.0),
                height: 20.0,
                color: Colors.grey.shade300,
              ),
              trailing: Container(
                height: 40.0,
                width: 40.0,
                color: Colors.transparent,
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        physics: const ClampingScrollPhysics(),
        controller: _scrollController,
        itemCount: _apps.length + (_loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (_loading && index == _apps.length) {
            return const Center(child: CircularProgressIndicator());
          }

          Application app = _apps[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: ListTile(
              leading: app is ApplicationWithIcon
                  ? CircleAvatar(
                      backgroundImage: MemoryImage(app.icon!),
                      backgroundColor: Colors.transparent,
                    )
                  : null,
              title: Text(app.appName),
              subtitle: Text(app.packageName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      FlutterClipboard.copy(app.packageName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Package name copied to clipboard!')),
                      );
                    },
                  ),
                  Checkbox(
                    value: _selectedPackages.contains(app.packageName),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected != null && selected) {
                          _selectedPackages.add(app.packageName);
                        } else {
                          _selectedPackages.remove(app.packageName);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _uninstallSelectedApps() async {
    if (_isRewardAdLoaded && _rewardedAd != null) {
      _proceedWithUninstallation();
      await Future.delayed(const Duration(seconds: 1));
      _apps.clear();
      _fetchInstalledApps();
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          ad.dispose();
          _loadRewardedAd(); // reload ad for the next time
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('$ad failed to show with error $error');
          ad.dispose();
          _loadRewardedAd(); // reload ad for the next time
        },
      );

      _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // Handle reward if needed
      });
    } else {
      _proceedWithUninstallation();
      await Future.delayed(const Duration(seconds: 2));
      _apps.clear();
      _fetchInstalledApps();
    }
  }

  void _proceedWithUninstallation() async {
    for (String app in _selectedPackages) {
      final intent = AndroidIntent(
        action: 'android.intent.action.DELETE',
        data: 'package:$app',
      );
      await intent.launch();
    }

    setState(() {
      _selectedPackages.clear();
    });
  }
}

class AppSearchDelegate extends SearchDelegate<String> {
  final List<Application> _apps;
  final Set<String> _selectedPackages;

  AppSearchDelegate(this._apps, this._selectedPackages);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestionsOrResults(query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestionsOrResults(query);
  }

  Widget _buildSuggestionsOrResults(String query) {
    List<Application> filteredApps = _apps
        .where((app) => app.appName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        Application app = filteredApps[index];
        return ListTile(
          leading: app is ApplicationWithIcon
              ? CircleAvatar(
                  backgroundImage: MemoryImage(app.icon!),
                  backgroundColor: Colors.transparent,
                )
              : null,
          title: Text(app.appName),
          subtitle: Text(app.packageName),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              FlutterClipboard.copy(app.packageName);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Package name copied to clipboard!')),
              );
            },
          ),
        );
      },
    );
  }
}
