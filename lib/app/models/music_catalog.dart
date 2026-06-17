class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    required this.price,
    this.unlockedByDefault = false,
  });

  final String id;
  final String name;
  final String description;
  final String assetPath;
  final int price;
  final bool unlockedByDefault;
}

class MusicCatalog {
  MusicCatalog._();

  static const defaultTrackId = 'rain';

  static const List<MusicTrack> all = [
    MusicTrack(
      id: 'rain',
      name: 'Gentle Rain',
      description: 'Soft rainfall for calm focus',
      assetPath: 'assets/music/rain.mp3',
      price: 0,
      unlockedByDefault: true,
    ),
    MusicTrack(
      id: 'rain_2',
      name: 'Heavy Rain',
      description: 'Steady downpour for deep focus',
      assetPath: 'assets/music/rain_2.mp3',
      price: 35,
    ),
    MusicTrack(
      id: 'city',
      name: 'City Ambience',
      description: 'Urban nightscape hum',
      assetPath: 'assets/music/city.mp3',
      price: 40,
    ),
    MusicTrack(
      id: 'cafe',
      name: 'Café Ambience',
      description: 'Warm coffee shop background chatter',
      assetPath: 'assets/music/cafe.mp3',
      price: 30,
    ),
    MusicTrack(
      id: 'space',
      name: 'Deep Space',
      description: 'Cosmic low-frequency atmosphere',
      assetPath: 'assets/music/space.mp3',
      price: 45,
    ),
    MusicTrack(
      id: 'forest_1',
      name: 'Forest Dawn',
      description: 'Birdsong and morning breeze',
      assetPath: 'assets/music/forest_1.mp3',
      price: 60,
    ),
    MusicTrack(
      id: 'forest_2',
      name: 'Forest Canopy',
      description: 'Deep woodland atmosphere',
      assetPath: 'assets/music/forest_2.mp3',
      price: 50,
    ),
  ];

  static MusicTrack byId(String id) {
    return all.firstWhere(
      (track) => track.id == id,
      orElse: () => all.first,
    );
  }
}
