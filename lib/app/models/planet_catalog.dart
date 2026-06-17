import 'package:flutter/material.dart';
import 'package:zenverse/app/views/shared/space_widgets.dart';

/// Metadata for a focus destination planet (journey + session display).
class PlanetDefinition {
  const PlanetDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.imageAssetPath,
    required this.glowColor,
    required this.unlockedByDefault,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final PlanetType type;
  final String imageAssetPath;
  final Color glowColor;
  final bool unlockedByDefault;
  final int price;
}

/// Central catalog for all focus destinations (store + journey + session).
class PlanetCatalog {
  PlanetCatalog._();

  static const earth = PlanetDefinition(
    id: 'earth',
    name: 'Earth',
    description: 'Your home base for focus',
    type: PlanetType.earth,
    imageAssetPath: 'assets/planets/earth.png',
    glowColor: Colors.blue,
    unlockedByDefault: true,
    price: 0,
  );

  static const mars = PlanetDefinition(
    id: 'mars',
    name: 'Mars',
    description: 'The red planet of determination',
    type: PlanetType.mars,
    imageAssetPath: 'assets/planets/mars.png',
    glowColor: Colors.orange,
    unlockedByDefault: true,
    price: 0,
  );

  static const moon = PlanetDefinition(
    id: 'moon',
    name: 'Moon',
    description: 'Calm lunar serenity',
    type: PlanetType.moon,
    imageAssetPath: 'assets/planets/moon.png',
    glowColor: Colors.grey,
    unlockedByDefault: false,
    price: 50,
  );

  static const venus = PlanetDefinition(
    id: 'venus',
    name: 'Venus',
    description: 'Radiant energy and warmth',
    type: PlanetType.venus,
    imageAssetPath: 'assets/planets/venus.png',
    glowColor: Colors.amber,
    unlockedByDefault: false,
    price: 80,
  );

  static const saturn = PlanetDefinition(
    id: 'saturn',
    name: 'Saturn',
    description: 'Ringed master of patience',
    type: PlanetType.saturn,
    imageAssetPath: 'assets/planets/saturn.png',
    glowColor: Colors.yellow,
    unlockedByDefault: false,
    price: 120,
  );

  static const jupiter = PlanetDefinition(
    id: 'jupiter',
    name: 'Jupiter',
    description: 'King of focus and power',
    type: PlanetType.jupiter,
    imageAssetPath: 'assets/planets/jupiter.png',
    glowColor: Colors.deepOrange,
    unlockedByDefault: false,
    price: 150,
  );

  static const neptune = PlanetDefinition(
    id: 'neptune',
    name: 'Neptune',
    description: 'Deep space concentration',
    type: PlanetType.neptune,
    imageAssetPath: 'assets/planets/neptune.png',
    glowColor: Colors.indigo,
    unlockedByDefault: false,
    price: 200,
  );

  static const uranus = PlanetDefinition(
    id: 'uranus',
    name: 'Uranus',
    description: 'Mysterious and serene',
    type: PlanetType.uranus,
    imageAssetPath: 'assets/planets/uranus.png',
    glowColor: Colors.teal,
    unlockedByDefault: false,
    price: 250,
  );

  static const List<PlanetDefinition> all = [
    earth,
    mars,
    moon,
    venus,
    saturn,
    jupiter,
    neptune,
    uranus,
  ];

  /// @deprecated Use [all] — kept for galaxy picker compatibility.
  static const List<PlanetDefinition> galaxyPlanets = all;

  static PlanetDefinition byId(String id) {
    for (final planet in all) {
      if (planet.id == id) return planet;
    }
    return earth;
  }
}
