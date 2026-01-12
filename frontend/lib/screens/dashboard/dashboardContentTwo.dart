import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:planos/screens/dashboard/indicator_box.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DashboardContentTwo extends StatefulWidget {
  final double globalScale;
  const DashboardContentTwo({super.key, this.globalScale = 1.0});

  @override
  State<DashboardContentTwo> createState() => _DashboardContentTwoState();
}

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
      child: Row(
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
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                overflow: TextOverflow.ellipsis,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: titleFont,
              ),
            ),
          ),
          if (trailing != null) trailing!,
          // show credits in header (compact)
        
        ],
      ),
    );
  }
}

class _DashboardContentTwoState extends State<DashboardContentTwo> {
  bool isLoading = true;
  String? error;

  // Dynamic data loaded from backend
  List<String> months = []; // e.g. ['Abr','Mai',...]
  List<double> analysesValues = [];
  List<double> revenueValues = [];
  List<double> newClientsValues = [];
  // requests as ordered list (label, value, percent)
  List<_RequestItem> requests = [];

  // companies (for pie)
  List<_CompanyItem> companies = [];
  int totalClientes = 0;
  int clientesNaoVinculados = 0;

  // indicators and totals (fallback safe values)
  int analysesLastWeek = 0;
  double revenueThisMonth = 0.0;
  int newClientsThisMonth = 0;
  String? topRequestLabel;
  int topRequestPercent = 0;

  int totalAnalyses = 0;
  int emAndamento = 0;
  double totalRevenue6m = 0.0;
  int creditsValidos = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboard();
    });
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) {
      setState(() {
        isLoading = false;
        error = 'Usuário não autenticado. Faça login.';
      });
      return;
    }

    final uri = Uri.parse('${dotenv.env['BASE_URL']}/dashboard/completo');

    try {
      final resp = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer ${user.token}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        setState(() {
          isLoading = false;
          error = 'Falha ao carregar dashboard (status: ${resp.statusCode})';
        });
        return;
      }

      final Map<String, dynamic> body = json.decode(resp.body);
      _parsePayload(body);

      setState(() {
        isLoading = false;
        error = null;
      });
    } catch (e, st) {
      debugPrint('Erro ao buscar dashboard: $e\n$st');
      setState(() {
        isLoading = false;
        error = 'Erro ao carregar dashboard: ${e.toString()}';
      });
    }
  }

  void _parsePayload(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
      if (v is num) return v.toDouble();
      return 0.0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
      if (v is num) return v.toInt();
      return 0;
    }

    final rawMonths = json['months'];
    if (rawMonths is List) {
      months = rawMonths.map((e) => e.toString()).toList();
    } else {
      months = ['Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set'];
    }

    final rawAnalyses = json['analysesValues'];
    if (rawAnalyses is List) {
      analysesValues = rawAnalyses.map((e) => toDouble(e)).toList();
    } else {
      analysesValues = [0, 0, 0, 0, 0, 0];
    }

    final rawRevenue = json['revenueValues'];
    if (rawRevenue is List) {
      revenueValues = rawRevenue.map((e) => toDouble(e)).toList();
    } else {
      revenueValues = [0, 0, 0, 0, 0, 0];
    }

    final rawNewClients = json['newClientsValues'];
    if (rawNewClients is List) {
      newClientsValues = rawNewClients.map((e) => toDouble(e).toInt().toDouble()).toList();
    } else {
      newClientsValues = [0, 0, 0, 0, 0, 0];
    }

    // parse requests (prefer last-month top list if present)
    requests.clear();
    final rawTopLast = json['top_requests_last_month'];
    if (rawTopLast is List && rawTopLast.isNotEmpty) {
      for (final item in rawTopLast) {
        if (item is Map) {
          final q = item['nome_produto_quimico']?.toString() ?? '';
          final b = item['nome_produto_biologico']?.toString() ?? '';
          final quantidade = toInt(item['quantidade_no_ultimo_mes']);
          final label = q.isNotEmpty && b.isNotEmpty ? '$q +\n$b' : (q + b);
          requests.add(_RequestItem(label: label, value: quantidade.toDouble(), percent: 0));
        }
      }
    }

    if (requests.isEmpty) {
      final rawRequests = json['requestsData'];
      if (rawRequests is List && rawRequests.isNotEmpty) {
        for (final item in rawRequests) {
          if (item is Map) {
            final label = (item['label'] ?? item['name'] ?? '').toString();
            final value = toDouble(item['value']);
            if (label.isNotEmpty) requests.add(_RequestItem(label: label, value: value, percent: toInt(item['percent'])));
          }
        }
      }
    }

    requests.sort((a, b) => b.value.compareTo(a.value));
    if (requests.length > 10) requests = requests.sublist(0, 10);

    // indicators
    final ind = json['indicators'] ?? {};
    analysesLastWeek = toInt(ind['analyses_last_week']);
    revenueThisMonth = toDouble(ind['revenue_this_month']);
    newClientsThisMonth = toInt(ind['new_clients_current_month']);
    topRequestLabel = ind['top_request_label']?.toString();
    topRequestPercent = toInt(ind['top_request_percent']);

    // totals
    final tot = json['totals'] ?? {};
    totalAnalyses = toInt(tot['total_analyses']);
    emAndamento = toInt(tot['em_andamento']);
    totalRevenue6m = toDouble(tot['total_revenue_6m']);
    creditsValidos = toInt(tot['credits_validos']);

    // --- Companies parsing for pie chart ---
    companies.clear();
    totalClientes = toInt(json['total_clientes']);
    clientesNaoVinculados = toInt(json['clientes_nao_vinculados']);

    final rawCompanies = json['empresas'];
    final palette = _defaultPalette();

    if (rawCompanies is List && rawCompanies.isNotEmpty) {
      int paletteIndex = 0;
      for (final item in rawCompanies) {
        if (item is Map) {
          final id = item['id'];
          final nome = item['nome']?.toString() ?? 'Empresa';
          final cnpj = item['cnpj']?.toString();
          final count = toInt(item['clientes_vinculados'] ?? item['clientes'] ?? item['count'] ?? 0);

          // try to pick color from several possible keys (corTema, cor_tema, color, color_hex)
          String? rawColor;
          if (item.containsKey('corTema')) rawColor = item['corTema']?.toString();
          if (rawColor == null && item.containsKey('cor_tema')) rawColor = item['cor_tema']?.toString();
          if (rawColor == null && item.containsKey('color')) rawColor = item['color']?.toString();
          if (rawColor == null && item.containsKey('color_hex')) rawColor = item['color_hex']?.toString();

          Color color;
          if (rawColor != null && rawColor.trim().isNotEmpty) {
            final parsed = _parseColorFromString(rawColor.trim());
            color = parsed ?? palette[paletteIndex % palette.length];
          } else {
            color = palette[paletteIndex % palette.length];
          }
          paletteIndex++;

          companies.add(_CompanyItem(id: id, nome: nome, cnpj: cnpj, count: count, color: color));
        }
      }
    }

    // add "Sem vínculo" as an extra slice if needed
    if (clientesNaoVinculados > 0) {
      companies.add(_CompanyItem(id: null, nome: 'Sem vínculo', cnpj: null, count: clientesNaoVinculados, color: Colors.grey.shade400));
    }

    // normalize length of series to months length
    final expectedLen = months.length;
    void _normalizeList(List<double> list) {
      if (list.length < expectedLen) {
        list.addAll(List<double>.filled(expectedLen - list.length, 0.0));
      } else if (list.length > expectedLen) {
        list.removeRange(expectedLen, list.length);
      }
    }

    _normalizeList(analysesValues);
    _normalizeList(revenueValues);
    _normalizeList(newClientsValues);
  }

  @override
  Widget build(BuildContext context) {
    final double globalScale = widget.globalScale;
    final cm = ColorManager.instance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final bool isSmall = maxWidth < 900;
        final double horizontalPadding = isSmall ? 12 * globalScale : 20 * globalScale;
        final double innerCardRadius = isSmall ? 20 * globalScale : 40 * globalScale;
        final double indicatorWidth = isSmall ? maxWidth - (horizontalPadding * 2) : 220 * globalScale;

        final double topIndicatorWidth = isSmall ? indicatorWidth : (indicatorWidth + 80 * globalScale);

        final double chartHeight = isSmall ? 220 * globalScale : 300 * globalScale;
//final double titleFontSize = isSmall ? 20 * globalScale : 24 * globalScale;

        final double gap = 12 * globalScale;

        return Card(
          color: cm.card.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(innerCardRadius),
            side: BorderSide(color: cm.primary.withOpacity(0.6), width: 1.2),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header integrated at the top of the card (keeps existing controls/functionality)
              ResultCardHeader(
                title: 'Painel Resumo',
                leadingIcon: Icons.view_quilt_rounded,
                primary: cm.primary,
                borderRadius: innerCardRadius,
                verticalPadding: 12 * globalScale,
                horizontalPadding: horizontalPadding,
                scale: globalScale,
                credit: creditsValidos,
                trailing: Padding(
                  padding: EdgeInsets.only(left: 8.0 * globalScale),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        SizedBox(
                          width: 22 * globalScale,
                          height: 22 * globalScale,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        )
                      else
                       
                      SizedBox(width: 8 * globalScale),
                    
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(height: 24 * globalScale),

                    if (isLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12 * globalScale),
                        child: Center(
                          child: Text(
                            'Carregando dados...',
                            style: TextStyle(
                              color: cm.explicitText.withOpacity(0.54),
                            ),
                          ),
                        ),
                      )
                    else if (error != null)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12 * globalScale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Erro: $error',
                              style: TextStyle(color: cm.emergency),
                            ),
                            SizedBox(height: 8 * globalScale),
                            ElevatedButton.icon(
                              onPressed: _fetchDashboard,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tentar novamente'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cm.primary,
                                foregroundColor: cm.text,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 12 * globalScale,
                          runSpacing: 12 * globalScale,
                          children: [
                            IndicatorBox(
                              icon: Icons.assessment_rounded,
                              label: 'Análises (7d)',
                              value: analysesLastWeek.toString(),
                              badge: 'semana',
                              width: indicatorWidth,
                              scale: globalScale,
                            ),
                            IndicatorBox(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Receita (este mês)',
                              value: 'R\$ ${revenueThisMonth.toStringAsFixed(2)}',
                              badge: revenueThisMonth > 0 ? 'novo' : '—',
                              width: indicatorWidth,
                              scale: globalScale,
                            ),
                            IndicatorBox(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'Novos Clientes (mês)',
                              value: newClientsThisMonth.toString(),
                              badge: '',
                              width: indicatorWidth,
                              scale: globalScale,
                            ),
                            IndicatorBox(
                              icon: Icons.pie_chart_outline_rounded,
                              label: 'Top solicitação',
                              value: topRequestLabel ?? (requests.isNotEmpty ? requests.first.label : '—'),
                              badge: '${topRequestPercent > 0 ? topRequestPercent : (requests.isNotEmpty ? requests.first.percent : 0)}%',
                              width: topIndicatorWidth,
                              scale: globalScale,
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16 * globalScale),

                    // RESPONSIVE LAYOUT (reestruturado):
                    // - In large screens: LEFT column contains analyses + requests (stacked close).
                    //   RIGHT column contains revenue, new clients, pie (stacked).
                    // - In small screens: stacked: analyses, revenue, new clients, pie, requests
                    isSmall
                        ? Column(
                            children: [
                              _cardWrapper(child: _buildAnalysesChart(chartHeight)),
                              SizedBox(height: gap),
                              _cardWrapper(child: _buildRevenueChart(180 * globalScale)),
                              SizedBox(height: gap),
                              _cardWrapper(child: _buildNewClientsChart(180 * globalScale)),
                              SizedBox(height: gap),
                              _cardWrapper(child: _buildCompaniesPieChart(220 * globalScale)),
                              SizedBox(height: gap),
                              _cardWrapper(child: _buildRequestsBarChart(260 * globalScale)),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT: analyses (top) + requests (bottom) -> keep them close
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        _cardWrapper(child: _buildAnalysesChart(chartHeight)),
                                        SizedBox(height: gap),
                                        _cardWrapper(child: _buildRequestsBarChart(260 * globalScale)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: gap),
                                  // RIGHT: revenue, new clients, pie
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        _cardWrapper(child: _buildRevenueChart(160 * globalScale)),
                                        SizedBox(height: gap),
                                        _cardWrapper(child: _buildNewClientsChart(140 * globalScale)),
                                        SizedBox(height: gap),
                                        _cardWrapper(child: _buildCompaniesPieChart(180 * globalScale)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: gap),
                              // summary column under the charts (still available)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: Container()), // keep spacing aligned
                                  SizedBox(width: gap),
                                  Expanded(
                                    flex: 2,
                                    child: _cardWrapper(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Resumo de clientes',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14 * globalScale,
                                              color: cm.explicitText,
                                            ),
                                          ),
                                          SizedBox(height: 10 * globalScale),
                                          Text(
                                            'Total de clientes: $totalClientes',
                                            style: TextStyle(color: cm.explicitText.withOpacity(0.72)),
                                          ),
                                          SizedBox(height: 6 * globalScale),
                                          Text(
                                            'Clientes sem vínculo: $clientesNaoVinculados',
                                            style: TextStyle(color: cm.explicitText.withOpacity(0.72)),
                                          ),
                                          SizedBox(height: 12 * globalScale),
                                          Text('Empresas (top):', style: const TextStyle(fontWeight: FontWeight.w700)),
                                          SizedBox(height: 8 * globalScale),
                                          ...companies.take(6).map((c) {
                                            return Padding(
                                              padding: EdgeInsets.symmetric(vertical: 4 * globalScale),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 12 * globalScale,
                                                    height: 12 * globalScale,
                                                    decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(3)),
                                                  ),
                                                  SizedBox(width: 8 * globalScale),
                                                  Expanded(child: Text(c.nome, style: TextStyle(color: cm.explicitText))),
                                                  SizedBox(width: 8 * globalScale),
                                                  Text('${c.count}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                    SizedBox(height: 12 * globalScale),
                    if (!isLoading && error == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Totais — análises:',
                          style: TextStyle(color: cm.explicitText.withOpacity(0.54), fontSize: 12 * globalScale),
                        ),
                      ),

                    SizedBox(height: isSmall ? 12 * globalScale : 18 * globalScale),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cardWrapper({required Widget child}) {
    final cm = ColorManager.instance;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * widget.globalScale)),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: cm.card.withOpacity(0.12),
      child: Padding(padding: EdgeInsets.all(12 * widget.globalScale), child: child),
    );
  }

  Widget _buildAnalysesChart(double height) {
    final cm = ColorManager.instance;
    final List<double> data = analysesValues.isNotEmpty ? analysesValues : List<double>.filled(months.length > 0 ? months.length : 6, 0.0);
    final int len = data.length == 0 ? 6 : data.length;
    final double maxY = (data.fold<double>(0, (prev, e) => math.max(prev, e)) + 1).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart_rounded, color: cm.primary, size: 18 * widget.globalScale),
            SizedBox(width: 8 * widget.globalScale),
            Text('Análises solicitadas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15 * widget.globalScale, color: cm.explicitText)),
          ],
        ),
        SizedBox(height: 10 * widget.globalScale),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: len.toDouble(),
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: cm.explicitText.withOpacity(0.12), strokeWidth: 1)),
              borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: cm.explicitText.withOpacity(0.25)), left: BorderSide(color: cm.explicitText.withOpacity(0.25)))),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 36 * widget.globalScale)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _bottomTitleWidgets, interval: 1)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((spot) {
                      final monthIndex = spot.x.toInt() - 1;
                      final monthLabel = (monthIndex >= 0 && monthIndex < months.length) ? months[monthIndex] : '';
                      final value = (monthIndex >= 0 && monthIndex < data.length) ? data[monthIndex] : spot.y;
                      return LineTooltipItem('${monthLabel}\n${value.toInt()}', TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * widget.globalScale));
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: List.generate(len, (i) => FlSpot((i + 1).toDouble(), data[i])),
                  barWidth: 3 * widget.globalScale,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [cm.primary.withOpacity(0.18), cm.primary.withOpacity(0.02)], stops: const [0.0, 1.0])),
                  color: cm.primary,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8 * widget.globalScale),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Período: ${months.isNotEmpty ? months.first : 'Abr'} → ${months.isNotEmpty ? months.last : 'Set'}', style: TextStyle(color: cm.explicitText.withOpacity(0.54), fontSize: 12 * widget.globalScale)),
            Text('Total: ${data.fold<int>(0, (a, b) => a + b.toInt())} análises', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12 * widget.globalScale, color: cm.explicitText)),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueChart(double height) {
    final cm = ColorManager.instance;
    final List<double> data = revenueValues.isNotEmpty ? revenueValues : List<double>.filled(months.length > 0 ? months.length : 6, 0.0);
    final int len = data.length == 0 ? 6 : data.length;
    final double maxVal = data.fold<double>(0, (prev, e) => math.max(prev, e));
    final double maxY = (maxVal * 1.25).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.paid_rounded, color: cm.primary, size: 18 * widget.globalScale),
            SizedBox(width: 8 * widget.globalScale),
            Text('Receita — Últimos meses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * widget.globalScale, color: cm.explicitText)),
          ],
        ),
        SizedBox(height: 10 * widget.globalScale),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final monthIndex = group.x.toInt() - 1;
                    final value = data[monthIndex];
                    final monthLabel = (monthIndex >= 0 && monthIndex < months.length) ? months[monthIndex] : '';
                    return BarTooltipItem('${monthLabel}\nR\$ ${value.toStringAsFixed(2)}', TextStyle(color: cm.text, fontWeight: FontWeight.bold, fontSize: 12 * widget.globalScale));
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: _revenueLeftInterval(maxVal), reservedSize: 44 * widget.globalScale, getTitlesWidget: (value, meta) => Text('R\$ ${value.toInt()}', style: TextStyle(fontSize: 11 * widget.globalScale, color: cm.explicitText.withOpacity(0.9))))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _bottomTitleWidgets, interval: 1)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(len, (i) => BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: data[i], width: 18 * widget.globalScale, borderRadius: BorderRadius.circular(6 * widget.globalScale), color: data[i] == 0 ? cm.explicitText.withOpacity(0.25) : cm.primary)])),
            ),
          ),
        ),
        SizedBox(height: 8 * widget.globalScale),
        Text('Valores em R. Total: R\$ ${totalRevenue6m.toStringAsFixed(2)}', style: TextStyle(color: cm.explicitText.withOpacity(0.54), fontSize: 12 * widget.globalScale)),
      ],
    );
  }

  Widget _buildNewClientsChart(double height) {
    final cm = ColorManager.instance;
    final List<double> data = newClientsValues.isNotEmpty ? newClientsValues : List<double>.filled(months.length > 0 ? months.length : 6, 0.0);
    final int len = data.length == 0 ? 6 : data.length;
    final double maxVal = data.fold<double>(0, (prev, e) => math.max(prev, e));
    final double maxY = (maxVal * 1.6).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: cm.primary, size: 18 * widget.globalScale),
            SizedBox(width: 8 * widget.globalScale),
            Text('Novos clientes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * widget.globalScale, color: cm.explicitText)),
          ],
        ),
        SizedBox(height: 10 * widget.globalScale),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final monthIndex = group.x.toInt() - 1;
                    final value = data[monthIndex].toInt();
                    final monthLabel = (monthIndex >= 0 && monthIndex < months.length) ? months[monthIndex] : '';
                    return BarTooltipItem('${monthLabel}\n${value} novo(s)', TextStyle(color: cm.text, fontWeight: FontWeight.bold, fontSize: 12 * widget.globalScale));
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _bottomTitleWidgets, interval: 1)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 28 * widget.globalScale)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(len, (i) {
                final val = data[i];
                return BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: val, width: 16 * widget.globalScale, borderRadius: BorderRadius.circular(6 * widget.globalScale), color: val == 0 ? cm.explicitText.withOpacity(0.25) : cm.primary)]);
              }),
            ),
          ),
        ),
        SizedBox(height: 8 * widget.globalScale),
        Text('Total novos clientes: ${data.fold<int>(0, (a, b) => a + b.toInt())}', style: TextStyle(color: cm.explicitText.withOpacity(0.54), fontSize: 12 * widget.globalScale)),
      ],
    );
  }

  Widget _buildRequestsBarChart(double height) {
    final cm = ColorManager.instance;
    final List<_RequestItem> data = requests.isNotEmpty ? requests : [_RequestItem(label: 'Sem dados', value: 0, percent: 0)];

    final int len = data.length;
    final double maxVal = data.fold<double>(0, (prev, e) => math.max(prev, e.value));
    final double maxY = (maxVal * 1.25).clamp(1.0, double.infinity);

    final barGroups = List.generate(len, (i) {
      final val = data[i].value;
      return BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: val, width: 22 * widget.globalScale, borderRadius: BorderRadius.circular(6 * widget.globalScale), color: val == 0 ? cm.explicitText.withOpacity(0.25) : _getPalette(i))]);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, color: cm.primary, size: 18 * widget.globalScale),
            SizedBox(width: 8 * widget.globalScale),
            Text('Principais análises', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * widget.globalScale, color: cm.explicitText)),
          ],
        ),
        SizedBox(height: 10 * widget.globalScale),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final idx = group.x.toInt() - 1;
                  final item = idx >= 0 && idx < data.length ? data[idx] : null;
                  if (item == null) return null;
                  return BarTooltipItem('${_shortLabel(item.label)}\n${item.value.toInt()}', TextStyle(color: cm.text, fontWeight: FontWeight.bold, fontSize: 12 * widget.globalScale));
                }),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40 * widget.globalScale, interval: (maxY / 4).ceilToDouble(), getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(fontSize: 11 * widget.globalScale, color: cm.explicitText.withOpacity(0.9))))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                  final idx = value.toInt() - 1;
                  final label = (idx >= 0 && idx < data.length) ? data[idx].label : '';
                  return SideTitleWidget(meta: meta, child: Container(width: 80 * widget.globalScale, child: Text(_shortLabel(label), textAlign: TextAlign.center, style: TextStyle(fontSize: 11 * widget.globalScale, color: cm.explicitText))));
                }, interval: 1, reservedSize: 60 * widget.globalScale)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).ceilToDouble()),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
        SizedBox(height: 8 * widget.globalScale),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(data.length, (i) {
          final item = data[i];
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * widget.globalScale),
            child: Row(
              children: [
                Container(width: 12 * widget.globalScale, height: 12 * widget.globalScale, decoration: BoxDecoration(color: _getPalette(i), borderRadius: BorderRadius.circular(3))),
                SizedBox(width: 8 * widget.globalScale),
                Expanded(child: Text(item.label, style: TextStyle(fontSize: 13 * widget.globalScale, color: cm.explicitText))),
                SizedBox(width: 8 * widget.globalScale),
                Text('${item.value.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, color: cm.explicitText)),
              ],
            ),
          );
        })),
        SizedBox(height: 8 * widget.globalScale),
        Text('Quantidade de análises solicitadas no mês anterior', style: TextStyle(color: cm.explicitText.withOpacity(0.54), fontSize: 12 * widget.globalScale)),
      ],
    );
  }

  Widget _buildCompaniesPieChart(double height) {
    final cm = ColorManager.instance;
    final List<_CompanyItem> data = companies.isNotEmpty ? companies : [_CompanyItem(id: null, nome: 'Sem dados', cnpj: null, count: 0, color: Colors.grey.shade400)];

    final double total = data.fold<double>(0, (p, e) => p + e.count.toDouble());
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < data.length; i++) {
      final c = data[i];
      final value = c.count.toDouble();
      final percent = total > 0 ? (value / total) * 100.0 : 0.0;
      sections.add(PieChartSectionData(
        color: c.color,
        value: value,
        radius: 40 * widget.globalScale,
        title: '${percent.round()}%',
        titleStyle: TextStyle(fontSize: 12 * widget.globalScale, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [Icon(Icons.pie_chart, color: cm.primary, size: 18 * widget.globalScale), SizedBox(width: 8 * widget.globalScale), Text('Cliente por empresa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * widget.globalScale, color: cm.explicitText))]),
        SizedBox(height: 10 * widget.globalScale),
        SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(flex: 2, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 20 * widget.globalScale, sectionsSpace: 4, startDegreeOffset: -90, borderData: FlBorderData(show: false), pieTouchData: PieTouchData(enabled: true)))),
              SizedBox(width: 12 * widget.globalScale),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: data.map((c) {
                    final pct = total > 0 ? ((c.count / total) * 100).round() : 0;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 6 * widget.globalScale),
                      child: Row(
                        children: [
                          Container(width: 12 * widget.globalScale, height: 12 * widget.globalScale, decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(3))),
                          SizedBox(width: 8 * widget.globalScale),
                          Expanded(child: Text(c.nome, style: TextStyle(color: cm.explicitText))),
                          SizedBox(width: 8 * widget.globalScale),
                          Text('${c.count}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 8 * widget.globalScale),
                          Text('($pct%)', style: TextStyle(color: cm.explicitText.withOpacity(0.6))),
                        ],
                      ),
                    );
                  }).toList()),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8 * widget.globalScale),
        Text('Total clientes: $totalClientes • Sem vínculo: $clientesNaoVinculados', style: TextStyle(color: cm.explicitText.withOpacity(0.54), fontSize: 12 * widget.globalScale)),
      ],
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    final idx = value.toInt() - 1;
    final text = (idx >= 0 && idx < months.length) ? months[idx] : '';
    return SideTitleWidget(meta: meta, child: Text(text, style: style.copyWith(fontSize: 12 * widget.globalScale, color: ColorManager.instance.explicitText)));
  }

  String _shortLabel(String label, {int maxLen = 18}) {
    final formatted = label.replaceAll('\n', ' - ');
    if (formatted.length <= maxLen) return formatted;
    return formatted.substring(0, maxLen - 1) + '…';
  }

  Color _getPalette(int index) {
    final List<Color> palette = _defaultPalette();
    return palette[index % palette.length];
  }

  List<Color> _defaultPalette() {
    return [
      ColorManager.instance.primary,
      Colors.orange,
      Colors.blueGrey,
      Colors.green.shade700,
      Colors.purple,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.brown,
    ];
  }

  Color? _parseColorFromString(String s) {
    try {
      String hex = s.replaceAll('#', '').trim();
      if (hex.length == 3) {
        // short form like 'f0a' -> 'ff00aa'
        hex = hex.split('').map((c) => c + c).join();
      }
      if (hex.length == 6) {
        hex = 'FF' + hex; // add alpha
      }
      final intVal = int.parse(hex, radix: 16);
      return Color(intVal);
    } catch (_) {
      return null;
    }
  }

  double _revenueLeftInterval(double maxVal) {
    if (maxVal <= 100) return 20;
    if (maxVal <= 500) return 100;
    if (maxVal <= 2000) return 500;
    return (maxVal / 4).ceilToDouble();
  }
}

class _RequestItem {
  final String label;
  final double value;
  final int percent;
  _RequestItem({required this.label, required this.value, required this.percent});
}

class _CompanyItem {
  final dynamic id;
  final String nome;
  final String? cnpj;
  final int count;
  final Color color;
  _CompanyItem({required this.id, required this.nome, required this.cnpj, required this.count, required this.color});
}
