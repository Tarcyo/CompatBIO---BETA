import 'package:flutter/material.dart';
import 'package:planos/screens/userProfile/fieldDecoration.dart';
import 'package:planos/styles/syles.dart';
// ajuste o path se necessário

class CityStateCountry extends StatelessWidget {
  final TextEditingController cityController;
  final String stateValue;
  final String countryValue;
  final List<String> states;
  final List<String> countries;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onCountryChanged;

  const CityStateCountry({
    super.key,
    required this.cityController,
    required this.stateValue,
    required this.countryValue,
    required this.states,
    required this.countries,
    required this.onStateChanged,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder para reagir a mudanças no ColorManager sem quebrar nada
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 720;

            if (narrow) {
              // mobile: City -> State -> Country (each full-width)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: cityController,
                    decoration: fieldDecoration(
                      hint: 'Cidade',
                      icon: Icons.location_city_rounded,
                      iconSize: 18,
                    ),
                    style: TextStyle(fontSize: 16, color: cm.explicitText),
                  ),
                  const SizedBox(height: 12),
                  // State full-width on mobile
                  InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.map_rounded,
                        color: cm.primary,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: cm.card.withOpacity(0.12),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: cm.card.withOpacity(0.20)),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: stateValue,
                        isExpanded: true,
                        items: states
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  style: TextStyle(fontSize: 15, color: cm.explicitText),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onStateChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Country on its own line
                  InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.public_rounded,
                        color: cm.primary,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: cm.card.withOpacity(0.12),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: cm.card.withOpacity(0.20)),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: countryValue,
                        isExpanded: true,
                        items: countries
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: TextStyle(fontSize: 15, color: cm.explicitText),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onCountryChanged,
                      ),
                    ),
                  ),
                ],
              );
            }

            // wide layout (desktop/tablet): city + small UF + country side-by-side
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 12),
                    child: TextFormField(
                      controller: cityController,
                      decoration: fieldDecoration(
                        hint: 'Cidade',
                        icon: Icons.location_city_rounded,
                        iconSize: 20,
                      ),
                      style: TextStyle(fontSize: 16, color: cm.explicitText),
                    ),
                  ),
                ),

                // UF pequeno
                SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.map_rounded,
                          color: cm.primary,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: cm.card.withOpacity(0.12),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: cm.card.withOpacity(0.20)),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: stateValue,
                          items: states
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: TextStyle(fontSize: 15, color: cm.explicitText),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: onStateChanged,
                        ),
                      ),
                    ),
                  ),
                ),

                // País
                SizedBox(
                  width: 160,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0, bottom: 12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.public_rounded,
                          color: cm.primary,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: cm.card.withOpacity(0.12),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: cm.card.withOpacity(0.20)),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: countryValue,
                          items: countries
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: TextStyle(fontSize: 15, color: cm.explicitText),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: onCountryChanged,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
