import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  runApp(const MaterialApp(home: HomeScreen()));
}

class Boisson {
  final String name;
  final String country;
  final String category;
  final String date;
  final String rating;
  final String comments;
  final String imagePath;

  String get fullName => '$name';



  Boisson({
    required this.name,
    required this.country,
    required this.category,
    required this.date,
    required this.rating,
    required this.comments,
    required this.imagePath ,
  });

  factory Boisson.fromLine(String line) {
    final parts = line.split(',').map((e) => e.replaceAll('"', '').trim()).toList();
    return Boisson(
      name: parts.length > 0 ? parts[0] : '',
      country: parts.length > 1 ? parts[1] : '',
      category: parts.length > 2 ? parts[2] : '',
      date: parts.length > 3 ? parts[3] : '',
      rating: parts.length > 4 ? parts[4] : '',
      comments: parts.length > 5 ? parts[5] : '',
      imagePath: parts.length > 6 ? parts[6] : 'assets/images/placeholder.png',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});


  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Boisson> boissons = [];
  List<Boisson> filteredBoissons = [];

  String? selectedCountry;
  String? selectedCategory;
  String searchQuery = '';
  String selectedSort = 'Nom';


  Future<void> saveBoissons(List<Boisson> boissons) async {
    final prefs = await SharedPreferences.getInstance();


    final jsonList = boissons.map((b) => {
      'name': b.name,
      'country': b.country,
      'category': b.category,
      'date': b.date,
      'rating': b.rating,
      'comments': b.comments,
      'imagePath': b.imagePath,
    }).toList();


    await prefs.setString('boissons', jsonEncode(jsonList));
    print('Boissons sauvegardées : $jsonList');
  }


  Future<bool> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('boissons');
    print('Données chargées depuis SharedPreferences : $data');
    if (data == null) return false;

    final decoded = jsonDecode(data) as List;
    boissons = decoded.map((e) => Boisson(
      name: e['name'],
      country: e['country'],
      category: e['category'],
      date: e['date'],
      rating: e['rating'],
      comments: e['comments'],
      imagePath: e['imagePath'],
    )).toList();

    filteredBoissons = List.from(boissons);
    setState(() {
      applyFilters();
    });
    return true;
  }



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initData(); // Premier chargement au démarrage
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
/*
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recharge toujours les données depuis SharedPreferences
      loadFromStorage().then((_) => setState(() {}));
    }
  } */

  Future<void> initData() async {
    final hasData = await loadFromStorage();
    if (!hasData) {
      await loadBoissons();
    }
  }

  Future<void> loadBoissons() async {
    final data = await rootBundle.loadString('assets/files/Boissons.txt');
    final list = data
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => Boisson.fromLine(line))
        .toList();

    setState(() {
      boissons = list;
      filteredBoissons = List.from(list);
    });
  }

  void applyFilters() {
    List<Boisson> result = boissons.where((b) {
      final matchCountry =
          selectedCountry == null || b.country == selectedCountry;
      final matchCategory =
          selectedCategory == null || b.category == selectedCategory;
      final matchSearch =
          searchQuery.isEmpty ||
              b.name.toLowerCase().contains(searchQuery.toLowerCase());

      return matchCountry && matchCategory && matchSearch;
    }).toList();


    switch (selectedSort) {
      case 'Note':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Date':
        result.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'Nom':
      default:
        result.sort((a, b) => a.name.compareTo(b.name));
    }

    setState(() {
      filteredBoissons = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final countries = ["Tous", ...boissons.map((b) => b.country).toSet()];
    final categories = ["Toutes", ...boissons.map((b) => b.category).toSet()];

    final w = MediaQuery.of(context).size.width;
    final isWide = w > 800;

    Widget filtersPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Filtres",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          const Text("Pays"),
          DropdownButton<String>(
            value: selectedCountry ?? "Tous",
            isExpanded: true,
            items: countries
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              selectedCountry = v == "Tous" ? null : v;
              applyFilters();
            },
          ),

          const SizedBox(height: 10),
          const Text("Catégorie"),
          DropdownButton<String>(
            value: selectedCategory ?? "Toutes",
            isExpanded: true,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              selectedCategory = v == "Toutes" ? null : v;
              applyFilters();
            },
          ),

          const SizedBox(height: 10),
          const Text("Trier par"),
          DropdownButton<String>(
            value: selectedSort,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: "Nom", child: Text("Nom")),
              DropdownMenuItem(value: "Note", child: Text("Note")),
              DropdownMenuItem(value: "Date", child: Text("Date")),
            ],
            onChanged: (v) {
              selectedSort = v!;
              applyFilters();
            },
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [


            // Logo + titre
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const SizedBox(width: 10),
                  const Text(
                    "Mes boissons",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            //  Barre de recherche
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Rechercher une boisson...",
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  searchQuery = v;
                  applyFilters();

                },
              ),
            ),

            // 4⃣ Zone filtres + grille
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isWide
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 220, child: filtersPanel()),
                    const SizedBox(width: 16),
                    Expanded(child: _grid()),
                  ],
                )
                    : Column(
                  children: [
                    ExpansionTile(
                      title: const Text("Filtres"),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: filtersPanel(),
                        )
                      ],
                    ),
                    Expanded(child: _grid()),
                  ],
                ),
              ),
            ),


            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final updatedList = await Navigator.push<List<Boisson>>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ajoutBoisson(
                        boisson: boissons[0],
                        boissonss: boissons,
                      ),
                    ),
                  );

                  await loadFromStorage();

                  if (updatedList != null) {
                    setState(() {
                      boissons = updatedList;
                      applyFilters();
                    });
                    saveBoissons(boissons);
                  } else {
                    setState(() {
                      applyFilters();
                    });
                  }
                },
                child: const Text("Ajouter une boisson"),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _grid() {
    return GridView.builder(
      itemCount: filteredBoissons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final b = filteredBoissons[index];
        return InkWell(
          onTap: () async {
            final updatedRaw = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContactDetailScreen(
                  boisson: b,
                  boissonss: boissons,
                ),
              ),
            );

            if (updatedRaw != null) {
              final updatedList = List<Boisson>.from(updatedRaw);
              setState(() {
                boissons = updatedList;
                applyFilters();
              });
              saveBoissons(boissons);
            }
          },
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    Image.asset(b.imagePath, height: 120, fit: BoxFit.contain),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                b.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }


}

class ajoutBoisson extends StatefulWidget {
  final Boisson boisson;
  final List<Boisson> boissonss;


  const ajoutBoisson({super.key, required this.boisson,  required this.boissonss});

  @override
  State<ajoutBoisson> createState() => _ajoutBoisson();
}

class _ajoutBoisson extends State<ajoutBoisson> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _imagePathController = TextEditingController();

  final List<String> imageOptions = [
    'assets/images/AïnSaïss.png',
    'assets/images/Bahia.png',
    'assets/images/CityDrink.png',
    'assets/images/Coca.png',
    'assets/images/evian.png',
    'assets/images/Fanta.png',
    'assets/images/Hawai.png',
    'assets/images/Jibal.png',
    'assets/images/Lipton.png',
    'assets/images/Mirinda.png',
    'assets/images/Monster.png',
    'assets/images/Nestea.png',
    'assets/images/Orangina.png',
    'assets/images/Pepsi.png',
    'assets/images/Poms.png',
    'assets/images/Redbul.png',
    'assets/images/Selecto.png',
    'assets/images/sidiAli.png',
    'assets/images/Volvic.png',
    'assets/images/Zagora.png',
  ];


  @override
  /*
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _countryController = TextEditingController();
    _categoryController = TextEditingController();
    _dateController = TextEditingController();
    _ratingController = TextEditingController();
    _commentsController = TextEditingController();
    _imagePathController = TextEditingController();
  } */


  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _ratingController.dispose();
    _commentsController.dispose();
    _imagePathController.dispose();
    super.dispose();
  }
  void saveForm() {
    final name = _nameController.text.trim();
    final country = _countryController.text.trim();
    final category = _categoryController.text.trim();
    final date = _dateController.text.trim();
    final rating = _ratingController.text.trim();
    final comments = _commentsController.text.trim();
    final imagePath = _imagePathController.text.trim();

    if (name.isEmpty ||
        country.isEmpty ||
        category.isEmpty ||
        date.isEmpty ||
        rating.isEmpty ||
        comments.isEmpty) {
      return;
    }

    final newBoisson = Boisson(
      name: name,
      country: country,
      category: category,
      date: date,
      rating: rating,
      comments: comments,
      imagePath: imagePath,
    );

    widget.boissonss.add(newBoisson);


  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter une boisson')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Champ Nom
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Champ Pays
              TextField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Pays',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Champ Catégorie

              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Soda', child: Text('Soda')),
                  DropdownMenuItem(value: 'Jus', child: Text('Jus')),
                  DropdownMenuItem(value: 'Eau', child: Text('Eau')),
                  DropdownMenuItem(value: 'Thé glacé', child: Text('Thé glacé')),
                  DropdownMenuItem(value: 'Boisson énergétique', child: Text('Boisson énergétique')),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoryController.text = value!;
                  });
                },
              ),
              const SizedBox(height: 10),



              // Champ Date
              TextField(
                controller: _dateController,
                readOnly: true, // Empêche la saisie manuelle
                decoration: const InputDecoration(
                  labelText: 'Date de sortie',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  // Ouvre le sélecteur de date
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000), // date min
                    lastDate: DateTime(2100),  // date max
                  );

                  if (pickedDate != null) {
                    // Formate la date en "yyyy-MM-dd"
                    String formattedDate =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2,'0')}-${pickedDate.day.toString().padLeft(2,'0')}";
                    setState(() {
                      _dateController.text = formattedDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),


              // Champ Note
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Note (0 à 5)"),
                onChanged: (v) {
                  double? value = double.tryParse(v);
                  if (value != null) {
                    if (value < 0) value = 0;
                    if (value > 5) value = 5;
                    setState(() {
                      var rating = value!;
                      _ratingController.text = rating.toString(); // met à jour le TextField
                      _ratingController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _ratingController.text.length),
                      );
                    });
                  }
                },
              ),

              const SizedBox(height: 10),

              // Champ Commentaire
              TextField(
                controller: _commentsController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Champ ImagePath
              DropdownButtonFormField<String>(
                value: _imagePathController.text.isNotEmpty ? _imagePathController.text : null,
                decoration: const InputDecoration(
                  labelText: 'Image',
                  border: OutlineInputBorder(),
                ),
                items: imageOptions
                    .map((img) => DropdownMenuItem(
                  value: img,
                  child: Row(
                    children: [
                      Image.asset(img, width: 40, height: 40, fit: BoxFit.cover),
                      const SizedBox(width: 8),
                      Text(img.split('/').last),
                    ],
                  ),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _imagePathController.text = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              /*
              onPressed: () async {
                    final updatedList = await Navigator.push<List<Boisson>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModificationBoisson(
                          boisson: widget.boisson,
                          boissonss: widget.boissonss,
                        ),
                      ),
                    );

                    // Si la liste est renvoyée après modification, mettre à jour l'état
                    if (updatedList != null) {

                      Navigator.pop(context, widget.boissonss);
                    }
                  },
                  child: const Text('Modifier'),
                ),
               */

              // Bouton Confirmer
              ElevatedButton(
                onPressed: ()  {

                  saveForm(); // modifie la boisson
                  Navigator.pop(context, widget.boissonss); // renvoie la liste mise à jour
                },
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ),
      ),
    );
  }


}


class ContactDetailScreen extends StatefulWidget {
  final Boisson boisson;
  final List<Boisson> boissonss;


  const ContactDetailScreen({super.key, required this.boisson,  required this.boissonss});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final boisson = widget.boisson;

    return Scaffold(
      appBar: AppBar(title: Text(boisson.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 6,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // empêche de prendre toute la hauteur
                    children: [
                      Text('Nom : ${boisson.name}', style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Pays : ${boisson.country}', style: const TextStyle(fontSize: 16)),
                      Text('Catégorie : ${boisson.category}', style: const TextStyle(fontSize: 16)),
                      Text('Date : ${boisson.date}', style: const TextStyle(fontSize: 16)),
                      Text('Note : ⭐ ${boisson.rating}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Commentaire : ${boisson.comments}', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => sendEmail(widget.boisson),
                  child: const Text('Envoyer par email'),
                ),
                ElevatedButton(
                  onPressed: () => searchInInternet(widget.boisson),
                  child: const Text('Recherche sur Internet'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updatedList = await Navigator.push<List<Boisson>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModificationBoisson(
                          boisson: widget.boisson,
                          boissonss: widget.boissonss,
                        ),
                      ),
                    );

                    if (updatedList != null) {
                      // 🔹 Mise à jour de HomeScreen
                      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                      homeState?.saveBoissons(updatedList);

                      Navigator.pop(context, updatedList);
                    }
                  },
                  child: const Text('Modifier'),
                ),


                ElevatedButton(
                  onPressed: () async {
                    // 1️⃣ Supprimer la boisson de la liste locale
                    setState(() {
                      widget.boissonss.remove(widget.boisson);
                    });

                    // 2️⃣ Sauvegarder les modifications dans SharedPreferences
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    if (homeState != null) {
                      await homeState.saveBoissons(widget.boissonss);
                    }

                    // 3️⃣ Recharger les données depuis SharedPreferences pour être sûr
                    if (homeState != null) {
                      await homeState.loadFromStorage();
                    }

                    // 4️⃣ Réappliquer les filtres pour mettre à jour l'affichage
                    if (homeState != null) {
                      homeState.applyFilters();
                    }

                    // 5️⃣ Retourner à l'écran précédent avec la liste mise à jour
                    Navigator.pop(context, widget.boissonss);
                  },
                  child: const Text('Supprimer'),
                ),




              ],
            ),
          ],
        ),
      ),
    );


  }
}

void sendEmail(Boisson boisson) async {
  final subject = Uri.encodeComponent('Infos sur la boisson ${boisson.name}');
  final body = Uri.encodeComponent(
      'Nom : ${boisson.name}\n'
          'Pays : ${boisson.country}\n'
          'Catégorie : ${boisson.category}\n'
          'Date : ${boisson.date}\n'
          'Note : ⭐ ${boisson.rating}\n'
          'Commentaire : ${boisson.comments}'
  );

  final mailt = 'mailto:?subject=$subject&body=$body';

  if (await canLaunchUrlString(mailt)) {
    await launchUrlString(mailt);
  } else {
    print('Impossible d’ouvrir l’application mail');
  }

}

void searchInInternet(Boisson boisson) async {
  final nom = boisson.name ;
  final info = Uri.encodeComponent(nom);
  final url = 'https://www.google.com/search?q=$info';

  if (await canLaunchUrlString(url)) {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  } else {
    print('Impossible d’ouvrir l’application mail');
  }

}

class ModificationBoisson extends StatefulWidget {
  final Boisson boisson;
  final List<Boisson> boissonss;

  const ModificationBoisson({
    super.key,
    required this.boisson,
    required this.boissonss,
  });

  @override
  State<ModificationBoisson> createState() => _ModificationBoissonState();
}

class _ModificationBoissonState extends State<ModificationBoisson> {
  late final TextEditingController _nameController;
  late final TextEditingController _countryController;
  late final TextEditingController _categoryController;
  late final TextEditingController _dateController;
  late final TextEditingController _ratingController;
  late final TextEditingController _commentsController;
  late final TextEditingController _imagePathController;

  final List<String> imageOptions = [
    'assets/images/AïnSaïss.png',
    'assets/images/Bahia.png',
    'assets/images/CityDrink.png',
    'assets/images/Coca.png',
    'assets/images/evian.png',
    'assets/images/Fanta.png',
    'assets/images/Hawai.png',
    'assets/images/Jibal.png',
    'assets/images/Lipton.png',
    'assets/images/Mirinda.png',
    'assets/images/Monster.png',
    'assets/images/Nestea.png',
    'assets/images/Orangina.png',
    'assets/images/Pepsi.png',
    'assets/images/Poms.png',
    'assets/images/Redbul.png',
    'assets/images/Selecto.png',
    'assets/images/sidiAli.png',
    'assets/images/Volvic.png',
    'assets/images/Zagora.png',
  ];

  @override
  void initState() {
    super.initState();
    // Initialisation des champs avec les valeurs existantes
    _nameController = TextEditingController(text: widget.boisson.name);
    _countryController = TextEditingController(text: widget.boisson.country);
    _categoryController = TextEditingController(text: widget.boisson.category);
    _dateController = TextEditingController(text: widget.boisson.date);
    _ratingController = TextEditingController(text: widget.boisson.rating);
    _commentsController = TextEditingController(text: widget.boisson.comments);
    _imagePathController = TextEditingController(text: widget.boisson.imagePath);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _ratingController.dispose();
    _commentsController.dispose();
    _imagePathController.dispose();
    super.dispose();
  }

  // Fonction pour modifier la boisson
  void saveForm() {
    final name = _nameController.text.trim();
    final country = _countryController.text.trim();
    final category = _categoryController.text.trim();
    final date = _dateController.text.trim();
    final rating = _ratingController.text.trim();
    final comments = _commentsController.text.trim();
    final imagePath = _imagePathController.text.trim();

    if (name.isEmpty ||
        country.isEmpty ||
        category.isEmpty ||
        date.isEmpty ||
        rating.isEmpty ||
        comments.isEmpty) {
      return; // ne fait rien si un champ est vide
    }

    final updatedBoisson = Boisson(
      name: name,
      country: country,
      category: category,
      date: date,
      rating: rating,
      comments: comments,
      imagePath: imagePath,
    );

    // Remplace l'ancienne boisson par la nouvelle à l'index correct
    final index = widget.boissonss.indexOf(widget.boisson);
    if (index != -1) {
      widget.boissonss[index] = updatedBoisson;
    }


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier Boisson')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Champ Nom
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Champ Pays
              TextField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Pays',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Champ Catégorie
              // Champ Catégorie
              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Soda', child: Text('Soda')),
                  DropdownMenuItem(value: 'Jus', child: Text('Jus')),
                  DropdownMenuItem(value: 'Eau', child: Text('Eau')),
                  DropdownMenuItem(value: 'Thé glacé', child: Text('Thé glacé')),
                  DropdownMenuItem(value: 'Boisson énergétique', child: Text('Boisson énergétique')),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoryController.text = value!;
                  });
                },
              ),
              const SizedBox(height: 10),


              // Champ Date
              // Champ Date
              TextField(
                controller: _dateController,
                readOnly: true, // Empêche la saisie manuelle
                decoration: const InputDecoration(
                  labelText: 'Date de sortie',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  // Ouvre le sélecteur de date
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000), // date min
                    lastDate: DateTime(2100),  // date max
                  );

                  if (pickedDate != null) {
                    // Formate la date en "yyyy-MM-dd"
                    String formattedDate =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2,'0')}-${pickedDate.day.toString().padLeft(2,'0')}";
                    setState(() {
                      _dateController.text = formattedDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),


              // Champ Note
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Note (0 à 5)"),
                onChanged: (v) {
                  double? value = double.tryParse(v);
                  if (value != null) {
                    if (value < 0) value = 0;
                    if (value > 5) value = 5;
                    setState(() {
                      var rating = value!;
                      _ratingController.text = rating.toString(); // met à jour le TextField
                      _ratingController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _ratingController.text.length),
                      );
                    });
                  }
                },
              ),

              const SizedBox(height: 10),

              // Champ Commentaire
              TextField(
                controller: _commentsController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Champ ImagePath
              DropdownButtonFormField<String>(
                value: _imagePathController.text.isNotEmpty ? _imagePathController.text : null,
                decoration: const InputDecoration(
                  labelText: 'Image',
                  border: OutlineInputBorder(),
                ),
                items: imageOptions
                    .map((img) => DropdownMenuItem(
                  value: img,
                  child: Row(
                    children: [
                      Image.asset(img, width: 40, height: 40, fit: BoxFit.cover),
                      const SizedBox(width: 8),
                      Text(img.split('/').last),
                    ],
                  ),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _imagePathController.text = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Bouton Confirmer
              ElevatedButton(
                onPressed: () {
                  saveForm(); // modifie la boisson

                  Navigator.pop(context, widget.boissonss); // renvoie la liste mise à jour
                },
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
