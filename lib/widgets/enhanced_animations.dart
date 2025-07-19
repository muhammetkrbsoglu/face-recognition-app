import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Gelişmiş animasyonlar ve UI polish
class EnhancedAnimations {
  
  /// Başarılı yüz tanıma animasyonu
  static void showSuccessAnimation(BuildContext context, String name) {
    HapticFeedback.lightImpact();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SuccessAnimationDialog(),
    );
    
    // 2 saniye sonra kapat
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }
  
  /// Hata animasyonu
  static void showErrorAnimation(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorAnimationDialog(message: message),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }
  
  /// Yüz tanıma progress animasyonu
  static void showProcessingAnimation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ProcessingAnimationDialog(),
    );
  }
}

/// Başarılı yüz tanıma dialog animasyonu
class SuccessAnimationDialog extends StatefulWidget {
  const SuccessAnimationDialog({super.key});

  @override
  State<SuccessAnimationDialog> createState() => _SuccessAnimationDialogState();
}

class _SuccessAnimationDialogState extends State<SuccessAnimationDialog> 
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleController.forward();
    _rotationController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * math.pi,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          spreadRadius: 10,
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Hata animasyonu dialog
class ErrorAnimationDialog extends StatefulWidget {
  final String message;
  const ErrorAnimationDialog({super.key, required this.message});

  @override
  State<ErrorAnimationDialog> createState() => _ErrorAnimationDialogState();
}

class _ErrorAnimationDialogState extends State<ErrorAnimationDialog> 
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value * 10, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Processing animasyonu dialog
class ProcessingAnimationDialog extends StatefulWidget {
  const ProcessingAnimationDialog({super.key});

  @override
  State<ProcessingAnimationDialog> createState() => _ProcessingAnimationDialogState();
}

class _ProcessingAnimationDialogState extends State<ProcessingAnimationDialog> 
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Smooth transition animasyonları
class SmoothTransitions {
  static Widget slideUpTransition(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value * 50),
          child: Opacity(
            opacity: 1 - value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  static Widget fadeInTransition(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  static Widget scaleTransition(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
} 