import 'package:flutter/material.dart';

class ScrollHintBanner extends StatefulWidget {
  final VoidCallback? onDismissed;
  final bool dismissOnInteraction;

  const ScrollHintBanner({
    super.key,
    this.onDismissed,
    this.dismissOnInteraction = true,
  });

  @override
  State<ScrollHintBanner> createState() => _ScrollHintBannerState();
}

class _ScrollHintBannerState extends State<ScrollHintBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = true;
  bool _instantDismiss = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // mantém o comportamento original de sumir após 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _triggerDismiss();
    });
  }

  bool _isMobilePortrait(Size size) {
    // Considera dispositivo móvel em retrato se altura > largura e o menor lado < 600dp.
    // Essa é uma heurística comum para distinguir phones de tablets/desktop.
    return size.height > size.width && size.shortestSide < 600;
  }

  void _triggerDismiss() {
    if (!mounted) return;
    if (!_visible) return;
    // para a animação de seta e inicia o fade-out
    if (_controller.isAnimating) _controller.stop();
    setState(() => _visible = false);
  }

/*  void _handleInteraction() {
    if (!widget.dismissOnInteraction) return;
    if (!mounted) return;
    if (!_visible) return;
    // torna o fade-out instantâneo e esconde imediatamente
    if (_controller.isAnimating) _controller.stop();
    setState(() {
      _instantDismiss = true;
      _visible = false;
    });
  }
*/
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shouldShow = _isMobilePortrait(size);

    // Se não for mobile em posição vertical, não renderiza o banner.
    if (!shouldShow) {
      // Garante que a animação não fique rodando desnecessariamente.
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return const SizedBox.shrink();
    }

    // Se deve mostrar e a animação ainda não está rodando, inicia-a.
    if (!_controller.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.isAnimating && _visible) {
          _controller.repeat(reverse: true);
        }
      });
    }

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: _instantDismiss ? Duration.zero : const Duration(seconds: 1),
      onEnd: () {
        if (!_visible) {
          widget.onDismissed?.call();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
      //  onTap: _handleInteraction,
       // onPanDown: (_) => _handleInteraction(),
       // onVerticalDragStart: (_) => _handleInteraction(),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.03,
            vertical: size.height * 0.01,
          ),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(size.width * 0.02),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Deslize para ver mais',
                style: TextStyle(
                  fontSize: size.width * 0.035,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: size.height * 0.005),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Transform.translate(
                  offset: Offset(
                    0,
                    Tween<double>(begin: 0, end: size.height * 0.015)
                        .animate(_controller)
                        .value,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: size.width * 0.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
