import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/dashboard/creditsWidget.dart';
import 'package:planos/screens/dashboard/dashboardStartCard.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ajuste o path se necessário

/// Reusable header with gradient, icon and trailing area.
/// Accepts a `scale` so we can enlarge text/icons consistently.
class ResultCardHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color primary;
  final double borderRadius;
  final Widget? trailing;
  final double verticalPadding;
  final double horizontalPadding;
  final double scale;
  final int credit;

  const ResultCardHeader({
    Key? key,
    required this.title,
    required this.leadingIcon,
    required this.primary,
    this.trailing,
    this.borderRadius = 18,
    this.verticalPadding = 14,
    this.horizontalPadding = 16,
    this.scale = 1.0,
    required this.credit,
  }) : super(key: key);

  Color _darken(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final primaryMid = _darken(primary, 0.08);
    final primaryEnd = _darken(primary, 0.20);
    final shadowColor = _darken(primary, 0.45).withOpacity(0.22);

    final iconSize = 16.0 * scale + 8.0;
    final titleFont = 18.0 * scale + 4.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.55, 1.0],
          colors: [primary, primaryMid, primaryEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(leadingIcon, color: Colors.white, size: iconSize),
              ),
              SizedBox(width: 12 * scale),
              Text(
                title,
                style: TextStyle(
                  overflow: TextOverflow.ellipsis,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: titleFont,
                ),
              ),
            ],
          ),

          if (trailing != null) trailing!,
          CreditsWidget(credits: credit, globalScale: scale),
        ],
      ),
    );
  }
}

class DashboardContentOne extends StatefulWidget {
  final double globalScale;
  const DashboardContentOne({super.key, this.globalScale = 1.0});

  @override
  State<DashboardContentOne> createState() => _DashboardContentOneState();
}

class _DashboardContentOneState extends State<DashboardContentOne> {
  bool loading = false;
  int credits = 0;
  int totalAnalyses = 0;
  int emAndamento = 0;
  String ultimoAnaliseLabel = 'sem registro';
  int saldoARealizar = 0;
  int planoCreditosMensal = 0;
  List<String> chartLabels = ['Jan', 'Fev', 'Mar', 'Abr'];
  List<int> chartValues = [0, 0, 0, 0];

  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (!userProv.isLoggedIn) return;
    setState(() => loading = true);
    try {
      final uri = Uri.parse("$baseUrl/dashboard/me");
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userProv.user!.token}',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          credits = (data['credits'] ?? 0) as int;
          totalAnalyses = (data['total_analises'] ?? 0) as int;
          emAndamento = (data['em_andamento'] ?? 0) as int;

          final ultimo = data['ultimo_analise'];
          if (ultimo != null) {
            final d = DateTime.tryParse(ultimo['data_solicitacao'].toString());
            ultimoAnaliseLabel = d != null
                ? '${d.toLocal().toString().split('.').first}'
                : 'registro';
          } else {
            ultimoAnaliseLabel = 'sem registro';
          }

          final mensal = data['mensal'] ?? {};
          planoCreditosMensal = (mensal['plano_creditos_mensal'] ?? 0) as int;
          final usados = (mensal['usados_no_mes'] ?? 0) as int;
          saldoARealizar =
              (mensal['saldo_a_realizar'] ??
                      max(planoCreditosMensal - usados, 0))
                  as int;

          final chart = data['chart'] ?? {};
          final labels = (chart['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList();
          final values = (chart['values'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList();

          if (labels != null &&
              values != null &&
              labels.length == values.length) {
            chartLabels = labels;
            chartValues = values;
          }
        });
      } else {
        // ignore errors silently for now
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => loading = false);
    }
  }

  double get globalScale => widget.globalScale;

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width;
    final bool isSmall = maxWidth < 600;
    final double horizontalPadding = isSmall
        ? 12 * globalScale
        : 20 * globalScale;
    final double innerCardRadius = isSmall
        ? 20 * globalScale
        : 40 * globalScale;
    final double statCardWidth = isSmall
        ? maxWidth - (horizontalPadding * 2)
        : 200 * globalScale;
    final double chartHeight = isSmall ? 200 * globalScale : 260 * globalScale;
    // double titleFontSize = isSmall ? 20 * globalScale : 26 * globalScale;

    // Reage a mudanças no ColorManager
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Card(
          color: cm.card.withOpacity(0.12), // fundo do card mais suave
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(innerCardRadius),
            side: BorderSide(color: cm.card.withOpacity(0.60), width: 1.2),
          ),
          elevation: 6,
          shadowColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header integrado no topo do Card (harmonizado com borderRadius)
              ResultCardHeader(
                credit: credits,
                title: 'Dashboard',
                leadingIcon: Icons.analytics_rounded,
                primary: cm.primary,
                borderRadius: innerCardRadius,
                verticalPadding: 12 * globalScale,
                horizontalPadding: horizontalPadding,
                scale: globalScale,
                trailing: Padding(
                  padding: EdgeInsets.only(left: 8.0 * globalScale),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.0 * globalScale),
                      onTap: () {}, // sem ação para não alterar funcionalidades
                      child: SizedBox(width: 0, height: 0),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  children: [
                    if (isSmall) ...[
                      const SizedBox(height: 8 * 1),
                    ] else ...[
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 12),
                    if (loading) LinearProgressIndicator(color: cm.primary),

                    //Divider(height: 24 * globalScale, color: cm.card.withOpacity(0.4)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 12 * globalScale,
                        runSpacing: 12 * globalScale,
                        children: [
                          StatCard(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Total de análises',
                            value: '$totalAnalyses',
                            width: statCardWidth,
                            scale: globalScale,
                          ),
                          StatCard(
                            icon: Icons.timer_rounded,
                            label: 'Saldo a realizar',
                            value: '$saldoARealizar',
                            width: statCardWidth,
                            scale: globalScale,
                          ),
                          StatCard(
                            icon: Icons.play_circle_outline_rounded,
                            label: 'Em andamento',
                            value: '$emAndamento',
                            width: statCardWidth,
                            scale: globalScale,
                          ),
                          StatCard(
                            icon: Icons.history_rounded,
                            label: 'Última análise',
                            value: ultimoAnaliseLabel,
                            width: statCardWidth,
                            scale: globalScale,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: isSmall ? 14 * globalScale : 20 * globalScale,
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            color: cm.primary,
                            size: 18 * globalScale,
                          ),
                          SizedBox(width: 6 * globalScale),
                          isSmall
                              ? Flexible(
                                  child: Text(
                                    'Análises Realizadas',
                                    style: TextStyle(
                                      fontSize: 16 * globalScale,
                                      fontWeight: FontWeight.w800,
                                      color: cm.explicitText,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Análises Solicitadas',
                                  style: TextStyle(
                                    fontSize: 20 * globalScale,
                                    fontWeight: FontWeight.w800,
                                    color: cm.explicitText,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: isSmall ? 10 * globalScale : 14 * globalScale,
                    ),

                    Card(
                      color: cm.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16 * globalScale),
                        side: BorderSide(color: cm.card.withOpacity(0.20)),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * globalScale,
                          vertical: 12 * globalScale,
                        ),
                        child: SizedBox(
                          height: chartHeight,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: (chartValues.length - 1).toDouble(),
                              minY: 0,
                              maxY: (chartValues.isNotEmpty
                                  ? (chartValues.reduce(max).toDouble() + 10)
                                  : 60),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 10,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: cm.card.withOpacity(0.12),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border(
                                  bottom: BorderSide(
                                    color: cm.card.withOpacity(0.30),
                                  ),
                                  left: BorderSide(
                                    color: cm.card.withOpacity(0.30),
                                  ),
                                  right: BorderSide(color: Colors.transparent),
                                  top: BorderSide(color: Colors.transparent),
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 10,
                                    reservedSize: isSmall
                                        ? 30 * globalScale
                                        : 40 * globalScale,
                                    getTitlesWidget: (v, meta) {
                                      final txt = v.toInt().toString();
                                      return SideTitleWidget(
                                        meta: meta,
                                        child: Text(
                                          txt,
                                          style: TextStyle(
                                            fontSize: 12 * globalScale,
                                            color: cm.explicitText.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, meta) =>
                                        _bottomTitleWidgets(
                                          v,
                                          meta,
                                          chartLabels,
                                        ),
                                    interval: 1,
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              // tooltip with white text for line chart values
                              lineTouchData: LineTouchData(
                                enabled: true,
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems:
                                      (List<LineBarSpot> touchedSpots) {
                                        return touchedSpots.map((spot) {
                                          final idx = spot.x.toInt();
                                          final monthLabel =
                                              (idx >= 0 &&
                                                  idx < chartLabels.length)
                                              ? chartLabels[idx]
                                              : '';
                                          final value =
                                              (idx >= 0 &&
                                                  idx < chartValues.length)
                                              ? chartValues[idx]
                                              : spot.y;
                                          return LineTooltipItem(
                                            '$monthLabel\n${value.toInt()}',
                                            TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12 * globalScale,
                                            ),
                                          );
                                        }).toList();
                                      },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    chartValues.length,
                                    (i) => FlSpot(
                                      i.toDouble(),
                                      chartValues[i].toDouble(),
                                    ),
                                  ),
                                  isCurved: true,
                                  barWidth: 3 * globalScale,
                                  dotData: FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      stops: const [0.1, 0.9],
                                      colors: [
                                        cm.primary.withOpacity(0.25),
                                        cm.primary.withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  color: cm.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 8 * globalScale),
                    Text(
                      'Evolução mensal mostrada acima.',
                      style: TextStyle(
                        color: cm.explicitText.withOpacity(0.7),
                        fontSize: 13 * globalScale,
                      ),
                    ),
                    SizedBox(
                      height: isSmall ? 12 * globalScale : 18 * globalScale,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomTitleWidgets(
    double value,
    TitleMeta meta,
    List<String> labels,
  ) {
    final cm = ColorManager.instance;
    final idx = value.toInt();
    final text = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: cm.explicitText,
    );
    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: style),
    );
  }
}
