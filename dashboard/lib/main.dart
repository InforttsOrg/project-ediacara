import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/features/symphony/ediacara_page.dart';
import 'src/theme/ediacara_theme.dart';

import 'design_skin.dart';
import 'package:infortts_shared/infortts_shared.dart';
void main() =>{
  AppDesignSkin.boot();
 runApp(const ProviderScope(child: EdiacaraApp()))
};

class EdiacaraApp extends StatelessWidget {
  const EdiacaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Ediacara — Market Symphony',
      debugShowCheckedModeBanner: false,
      theme: AcousticTheme.applySkinTo(EdiacaraTheme.dark(), AppDesignSkin.skin),
      home: const EdiacaraPage(),
    );
  }
}
