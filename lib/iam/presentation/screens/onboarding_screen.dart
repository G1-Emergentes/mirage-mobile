import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), widget.onComplete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      minimum: const EdgeInsets.only(top: 48, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final height = bounds.maxHeight;
              return Stack(
                children: [
                  Positioned(
                    top: height * .171,
                    left: bounds.maxWidth * .118,
                    child: SizedBox(
                      width: 330,
                      height: 244,
                      child: Center(
                        child: Transform.rotate(
                          angle: -23 * math.pi / 180,
                          child: const MirageAsset(
                            'onboarding_0_imgOrbit.svg',
                            width: 300,
                            height: 138,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: height * .40,
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MirageWordmark(size: 87),
                      ),
                    ),
                  ),
                  Positioned(
                    top: height * .565,
                    left: 0,
                    right: 0,
                    child: const Text(
                      'by ReWear',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  Positioned(
                    top: height * .311,
                    right: 48,
                    child: const Text(
                      '✦',
                      style: TextStyle(fontSize: 42, color: MirageColors.pink),
                    ),
                  ),
                  Positioned(
                    top: height * .734,
                    left: 0,
                    right: 0,
                    child: const Text(
                      'Your wardrobe, reimagined.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Positioned(
                    bottom: 47,
                    left: 0,
                    right: 0,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MirageAsset(
                          'onboarding_0_imgStatusDot.svg',
                          width: 6,
                          height: 6,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'REAL CLOTHES. NEW POSSIBILITIES.',
                          style: TextStyle(
                            fontSize: 10,
                            color: MirageColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _index = 0;
  static const _headlines = [
    'Your closet.\nDigital.',
    'Style what you\nalready own.',
    'See more. Try\nmore.',
  ];
  static const _copy = [
    'Keep your clothes in one place and rediscover what you already own.',
    'Create new combinations using your real wardrobe.',
    'Explore accessories in 3D, try them in AR, and generate personalized outfit previews.',
  ];
  @override
  Widget build(BuildContext context) => MirageScreen(
    topPadding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const MirageWordmark(size: 24),
            TextButton(
              onPressed: widget.onComplete,
              style: TextButton.styleFrom(foregroundColor: MirageColors.muted),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: [
            'Your digital wardrobe',
            'Combine clothes you own',
            'Explore 3D, AR and outfit previews',
          ][_index],
          image: true,
          child: LayoutBuilder(
            builder: (context, bounds) => SizedBox(
              width: bounds.maxWidth,
              height: bounds.maxWidth * 373 / 342,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 342,
                  height: 373,
                  child: MediaQuery.withNoTextScaling(
                    child: switch (_index) {
                      0 => const _ClosetArt(),
                      1 => const _OutfitArt(),
                      _ => const _InnovationArt(),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Semantics(
          label: 'Introduction ${_index + 1} of 3',
          child: SizedBox(
            height: 16,
            child: Row(
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 7),
                  width: i == _index ? 28 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? MirageColors.pink
                        : MirageColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _headlines[_index],
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        Text(_copy[_index], style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        MirageButton(
          label: _index == 2 ? 'Get Started' : 'Continue',
          onPressed: () {
            if (_index == 2) {
              widget.onComplete();
            } else {
              setState(() => _index++);
            }
          },
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.color = Colors.white});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        height: 1.2,
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ClosetArt extends StatelessWidget {
  const _ClosetArt();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: MirageColors.lavender,
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'THE EVERYDAY ARCHIVE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            _Badge('ALL YOURS'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _slot('onboarding_1_imgFashionObject.png', 158, 146, 152),
            const SizedBox(width: 10),
            _slot('onboarding_1_imgFashionObject1.png', 158, 144, 151),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _slot('onboarding_1_imgFashionObject2.png', 129, 147, 121),
            const SizedBox(width: 10),
            _slot(
              'onboarding_1_imgFashionObject3.png',
              129,
              143,
              121,
              color: MirageColors.lime,
            ),
          ],
        ),
      ],
    ),
  );
  Widget _slot(
    String file,
    double height,
    double imageWidth,
    double imageHeight, {
    Color color = MirageColors.paper,
  }) => Expanded(
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.topLeft,
        child: MirageAsset(file, width: imageWidth, height: imageHeight),
      ),
    ),
  );
}

class _OutfitArt extends StatelessWidget {
  const _OutfitArt();
  Widget _rotated(
    String asset,
    double x,
    double y,
    double bw,
    double bh,
    double width,
    double height,
    double degrees,
  ) => Positioned(
    left: x,
    top: y,
    width: bw,
    height: bh,
    child: Center(
      child: Transform.rotate(
        angle: degrees * math.pi / 180,
        child: MirageAsset(asset, width: width, height: height),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: MirageColors.blue,
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        _rotated(
          'onboarding_2_imgOutfitOrbit.svg',
          22,
          9.74,
          342.625,
          289.417,
          299,
          228,
          -13,
        ),
        _rotated(
          'onboarding_2_imgFashionObject.png',
          11,
          -13.21,
          227.695,
          225.261,
          197,
          194,
          -10,
        ),
        _rotated(
          'onboarding_2_imgFashionObject1.png',
          130.82,
          43,
          205.157,
          298.257,
          164,
          276,
          9,
        ),
        _rotated(
          'onboarding_2_imgFashionObject2.png',
          16,
          208.48,
          183.221,
          136.411,
          169,
          114,
          -8,
        ),
        _rotated(
          'onboarding_2_imgFashionObject3.png',
          171.09,
          239,
          124.659,
          133.902,
          103,
          115,
          12,
        ),
        Positioned(
          left: 19,
          top: 5.28,
          width: 133.328,
          height: 32.425,
          child: Center(
            child: Transform.rotate(
              angle: -5 * math.pi / 180,
              child: const _Badge(
                'REMIX. REWEAR. REPEAT.',
                color: MirageColors.lime,
              ),
            ),
          ),
        ),
        const Positioned(
          left: 295,
          top: 17,
          child: Text(
            '✦',
            style: TextStyle(fontSize: 29, color: MirageColors.pink),
          ),
        ),
      ],
    ),
  );
}

class _InnovationArt extends StatelessWidget {
  const _InnovationArt();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: MirageColors.lavender,
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          left: 13,
          top: 16,
          width: 190,
          height: 157,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE6E8EA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Stack(
              children: [
                Positioned(left: 12, top: 12, child: _Badge('EXPLORE IN 3D')),
                Positioned(
                  left: 12,
                  top: 33,
                  child: MirageAsset(
                    'onboarding_3_imgFashionObject.png',
                    width: 169,
                    height: 102,
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 135,
                  child: MirageAsset(
                    'onboarding_3_imgRotate3D.svg',
                    width: 18,
                    height: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 180,
          top: 54,
          width: 148,
          height: 248,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MirageColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: const MirageAsset(
                'onboarding_3_imgArCameraPreview.png',
                width: 136,
                height: 235,
              ),
            ),
          ),
        ),
        const Positioned(
          left: 195,
          top: 71,
          child: _Badge('AR CAMERA', color: MirageColors.lime),
        ),
        Positioned(
          left: 17,
          top: 205,
          width: 146,
          height: 152,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: const MirageAsset(
                    'onboarding_3_imgAiOutfitPreview.png',
                    width: 136,
                    height: 114,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '✦ YOUR AI PREVIEW',
                  maxLines: 1,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 273,
          top: 15,
          child: Text(
            '✦',
            style: TextStyle(fontSize: 28, color: MirageColors.pink),
          ),
        ),
      ],
    ),
  );
}
