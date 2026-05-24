/// Voltera Design System — entry point.
///
/// Folosire:
///   import 'package:voltera/design/design.dart';
///
/// Toate componentele, tokens-urile semantice si scale-urile sunt exportate
/// de aici. Pe `context.tokens` ai aliasurile semantice (surface, accent,
/// danger, etc.). Tipografia se citeste prin VType.*. Spacing prin VSpace.*.
library;

// Tokens
export 'tokens/colors.dart';
export 'tokens/elevation.dart';
export 'tokens/motion.dart';
export 'tokens/radius.dart';
export 'tokens/spacing.dart';
export 'tokens/typography.dart';

// Theme
export 'theme/voltera_theme.dart';
export 'theme/voltera_tokens.dart';

// Components
export 'components/connection_pill.dart';
export 'components/empty_state.dart';
export 'components/live_arc_meter.dart';
export 'components/metric_block.dart';
export 'components/mini_sparkline.dart';
export 'components/status_badge.dart';
export 'components/status_dot.dart';
export 'components/v_app_bar.dart';
export 'components/v_card.dart';
export 'components/v_list_tile.dart';
export 'components/v_scaffold.dart';
export 'components/v_section.dart';
export 'components/value_row.dart';
