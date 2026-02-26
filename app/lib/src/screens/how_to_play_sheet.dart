import 'package:flutter/material.dart';

Future<void> showHowToPlaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0D1622),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.84,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'How To Play Infection Zone',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GuideTitle('Objective'),
                      _GuideText('Humans must survive 3 minutes. Infected must infect every human before time ends.'),
                      SizedBox(height: 12),
                      _GuideTitle('Controls (Twin Stick)'),
                      _GuideText('Left stick: move'),
                      _GuideText('Right stick: aim direction (line + reticle shown in world)'),
                      _GuideText('FIRE button: always visible, only enabled for humans'),
                      SizedBox(height: 12),
                      _GuideTitle('Important'),
                      _GuideText('You do NOT pick up a gun. Humans spawn with stun pistol equipped.'),
                      _GuideText('Use Create Room from menu if you want a fresh private room with code.'),
                      _GuideText('Supply drops give extra ammo/flare items when events trigger.'),
                      SizedBox(height: 12),
                      _GuideTitle('Human Play Loop'),
                      _GuideText('1. Keep moving with left stick'),
                      _GuideText('2. Aim with right stick and tap FIRE to stun infected'),
                      _GuideText('3. Use FLARE to blind infected and reveal Patient Zero'),
                      _GuideText('4. Use DASH/BUILD/GENERATOR based on pressure'),
                      SizedBox(height: 12),
                      _GuideTitle('Infected Play Loop'),
                      _GuideText('1. Chase and corner humans'),
                      _GuideText('2. Patient Zero uses SCREAM and INVIS to create openings'),
                      _GuideText('3. Gen2 uses POUNCE to close gaps'),
                      _GuideText('4. Use minimap to locate isolated targets'),
                      SizedBox(height: 12),
                      _GuideTitle('What You See On Screen'),
                      _GuideText('Top-left: team counts'),
                      _GuideText('Top-center: timer'),
                      _GuideText('Top-right: minimap with all players'),
                      _GuideText('Bottom-center: equipped weapon + ammo/flare'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Start / Continue'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GuideTitle extends StatelessWidget {
  const _GuideTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFFECC04B), fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}

class _GuideText extends StatelessWidget {
  const _GuideText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFE5EEF9), fontSize: 14, height: 1.35),
      ),
    );
  }
}
