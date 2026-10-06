// GENERATED FILE — DO NOT EDIT BY HAND.
// Regenerate: python3 tools/design-pipeline/generate.py
// Source skill: ~/.config/opencode/skills/perspective/DESIGN.md
//
//   Design : Perspective
//   Mode   : dark
//   Skill  : perspective
//
// Audit at generation time (WCAG on the generated panel surface):
//   body contrast  15.30:1   subtext contrast 6.36:1   accent 6.78:1
//
// The Infortts 3D emblem, logo and shell chrome are NOT affected by this file —
// they stay canonical Rocky Vision. Only the product surface is restyled, which
// is how each app ends up visually distinct while remaining on-brand.
//
// Prefer composing `shared` primitives (AcousticSurface, AcousticButton,
// AcousticText, AcousticSection…) over hand-rolled decoration; they read these
// values automatically.

import 'package:flutter/material.dart';

import 'package:infortts_shared/infortts_shared.dart';

/// Design skin for **ediacara/dashboard**.
class AppDesignSkin {
  const AppDesignSkin._();

  static const String appName = 'ediacara/dashboard';
  static const String skill = 'perspective';
  static const String designName = 'Perspective';
  static const bool isDark = true;

  /// Apply before `runApp`.
  static void boot({Brightness brightness = Brightness.dark}) {
    InforttsDesign.boot(skin, initialBrightness: brightness);
  }

  static const AcousticDynamicThemeConfig skin = AcousticDynamicThemeConfig(
    // accents
    primaryColor: Color(0xFF02B41F),
    secondaryColor: Color(0xFF027FB4),
    primaryDimColor: Color(0xFF02450F),
    successColor: Color(0xFF16A34A),
    dangerColor: Color(0xFFDC2626),
    warnColor: Color(0xFFD97706),

    // surfaces
    darkBg: Color(0xFF040B0B),
    darkPanelBg: Color(0xFF021508),
    lightBg: Color(0xFFFFFFFF),
    lightPanelBg: Color(0xFFFFFFFF),
    obsidianColor: Color(0xFF04190D),
    activeCardColor: Color(0xFF3C4C44),

    // text (dark palette)
    titaniumColor: Color(0xFFE2E8F0),
    steelColor: Color(0xFF8D9898),
    midGrayColor: Color(0xFF3C4C44),
    // Drives AcousticColors.lightOnBackground/lightOnSurface, so it must be
    // the LIGHT palette's ink — the dark titanium would be invisible on a light
    // panel. Light-mode subtext reuses steelColor via lightOnSurfaceVariant.
    textOnSurface: Color(0xFF111827),
    lightSubTextColor: Color(0xFF7C8088),
    outlineColor: Color(0xFF3C4C44),

    // type
    fontFamily: 'Poppins',
    monoFamily: 'JetBrains Mono',
    displayFamily: 'Oswald',
    bodyTextSize: 16,
    headingTextSize: 32,

    // geometry
    cardBorderRadius: 8,
    radiusSm: 4,
  );
}

