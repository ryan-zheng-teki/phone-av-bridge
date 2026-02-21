package org.autobyteus.phoneavbridge.pairing

import org.autobyteus.phoneavbridge.model.DiscoveredHost

enum class HostSelectionAction {
  PAIR,
  SWITCH,
  UNPAIR,
  SELECT_REQUIRED,
}

data class HostSelectionSnapshot(
  val candidates: List<DiscoveredHost>,
  val selectedBaseUrl: String?,
  val explicitSelection: Boolean,
  val action: HostSelectionAction,
)

object HostSelectionState {
  fun reconcile(
    candidates: List<DiscoveredHost>,
    selectedBaseUrl: String?,
    explicitSelection: Boolean,
    paired: Boolean,
    pairedBaseUrl: String?,
  ): HostSelectionSnapshot {
    val normalized = dedupeByBaseUrl(candidates)
    if (normalized.isEmpty()) {
      return HostSelectionSnapshot(
        candidates = emptyList(),
        selectedBaseUrl = null,
        explicitSelection = false,
        action = if (paired) HostSelectionAction.UNPAIR else HostSelectionAction.SELECT_REQUIRED,
      )
    }

    val hasSelected = selectedBaseUrl != null && normalized.any { it.baseUrl == selectedBaseUrl }
    val currentPairedBaseUrl = pairedBaseUrl?.trim().orEmpty()

    var effectiveSelected = if (hasSelected) selectedBaseUrl else null
    var effectiveExplicit = explicitSelection && hasSelected

    if (normalized.size > 1 && !effectiveExplicit) {
      if (paired) {
        val current = pairedBaseUrl?.trim().orEmpty()
        effectiveSelected = normalized.firstOrNull { it.baseUrl == current }?.baseUrl
      } else {
        effectiveSelected = null
      }
    } else if (effectiveSelected == null && normalized.size == 1) {
      effectiveSelected = normalized.first().baseUrl
      effectiveExplicit = false
    }

    val action = if (!paired) {
      if (effectiveSelected == null) HostSelectionAction.SELECT_REQUIRED else HostSelectionAction.PAIR
    } else {
      when {
        currentPairedBaseUrl.isBlank() && effectiveSelected != null -> HostSelectionAction.PAIR
        currentPairedBaseUrl.isBlank() -> HostSelectionAction.SELECT_REQUIRED
        effectiveSelected == null -> HostSelectionAction.SELECT_REQUIRED
        effectiveSelected == currentPairedBaseUrl -> HostSelectionAction.UNPAIR
        else -> HostSelectionAction.SWITCH
      }
    }

    return HostSelectionSnapshot(
      candidates = normalized,
      selectedBaseUrl = effectiveSelected,
      explicitSelection = effectiveExplicit,
      action = action,
    )
  }

  private fun dedupeByBaseUrl(candidates: List<DiscoveredHost>): List<DiscoveredHost> {
    val deduped = LinkedHashMap<String, DiscoveredHost>()
    candidates.forEach { candidate ->
      deduped[candidate.baseUrl] = candidate
    }
    return deduped.values.toList()
  }
}
