import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/dashboard/dashboardContent.dart';
import 'package:planos/screens/dashboard/dashboardContentTwo.dart';
import 'package:planos/utils/scroll_hint_banner.dart';

import 'package:provider/provider.dart';

// import do ScrollHintBanner (adicionado conforme padrão)

/// Página principal com dropdown para escolher entre dashboard 1 e 2
class DashboardsPage extends StatefulWidget {
  const DashboardsPage({super.key});
  @override
  State<DashboardsPage> createState() => _DashboardsPageState();
}

class _DashboardsPageState extends State<DashboardsPage> {
  // flag local para controlar exibição do banner
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    String selected = "Dashboard 2";

    print(Provider.of<UserProvider>(context, listen: true).user!.tipoUsuario);
    if (Provider.of<UserProvider>(
      context,
      listen: true,
    ).user!.tipoUsuario!.toString().contains('Cliente')) {
      selected = "Dashboard 1";
    }
    final media = MediaQuery.of(context).size;
    final vw = media.width;
    // final vh = media.height;

    // Margens laterais pequenas em desktop para que o card "preencha" bem a tela
    final horizontalGap = vw > 1400 ? 40.0 : 24.0; // total left+right
    // final verticalGap = vh > 900 ? 36.0 : 24.0; // total top+bottom

    final cardWidth = (vw - horizontalGap).clamp(360.0, vw);

    // escala moderada para desktop (legibilidade sem exageros)
    final globalScale = vw > 1400 ? 1.18 : (vw > 1200 ? 1.08 : 1.0);

    // Observação: removi AppBar e qualquer outro elemento para garantir que só
    // apareçam o dropdown e o card do dashboard.
    return Scaffold(
      // fundo simples; nada além do dropdown e do card estará visível
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: cardWidth,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * globalScale,
                    vertical: 12 * globalScale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Somente o dropdown — sem ícone, sem texto, nada mais.
                      Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.shade100),
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8 * globalScale,
                            ),
                            child: SizedBox(width: 1),
                          ),
                        ),
                      ),

                      // Pequeno espaçamento invisível entre dropdown e card (opcional)
                      SizedBox(height: 12 * globalScale),

                      // Conteúdo (um dos dois dashboards)
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (!_bannerDismissed &&
                                (notification is ScrollStartNotification ||
                                    notification.metrics.pixels > 0)) {
                              setState(() {
                                _bannerDismissed = true;
                              });
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            child: selected == 'Dashboard 1'
                                ? DashboardContentOne(globalScale: globalScale)
                                : DashboardContentTwo(globalScale: globalScale),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Banner posicionado na parte inferior; exibido somente se não descartado
            if (!_bannerDismissed)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: ScrollHintBanner(
                    onDismissed: () {
                      if (mounted) {
                        setState(() {
                          _bannerDismissed = true;
                        });
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
