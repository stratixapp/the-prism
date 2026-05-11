// lib/features/home/presentation/widgets/agent_spectrum_preview.dart
// Shows all 10 agent avatar chips in a horizontal spectrum strip.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/agent_model.dart';

class AgentSpectrumPreview extends StatelessWidget {
  const AgentSpectrumPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final agents = AgentRegistry.all;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: agents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final agent = agents[i];
          return Tooltip(
            message: '${agent.name} · ${agent.role}',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: agent.bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                    color: agent.color.withOpacity(0.4), width: 1),
              ),
              child: Center(
                child: Text(
                  agent.initials,
                  style: TextStyle(
                    color: agent.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
