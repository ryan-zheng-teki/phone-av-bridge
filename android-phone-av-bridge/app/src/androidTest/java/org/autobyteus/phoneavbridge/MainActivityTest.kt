package org.autobyteus.phoneavbridge

import android.content.Context
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isChecked
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.isNotChecked
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.espresso.matcher.ViewMatchers.withText
import org.autobyteus.phoneavbridge.model.ResourceToggleState
import org.autobyteus.phoneavbridge.service.ResourceService
import org.autobyteus.phoneavbridge.store.AppPrefs
import org.hamcrest.Matchers.anyOf
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ExternalResource
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityTest {
  @get:Rule(order = 0)
  val resetStateRule: ExternalResource = object : ExternalResource() {
    override fun before() {
      val context = ApplicationProvider.getApplicationContext<Context>()
      AppPrefs.clearAll(context)
      context.stopService(ResourceService.buildIntent(context, ResourceToggleState()))
    }
  }

  @get:Rule(order = 1)
  val scenarioRule = ActivityScenarioRule(MainActivity::class.java)

  @Test
  fun defaultStateAndPairingToggleAreVisible() {
    onView(withId(R.id.statusText)).check(matches(withText(R.string.status_disconnected)))
    onView(withId(R.id.cameraSwitch)).check(matches(isDisplayed()))
    onView(withId(R.id.micSwitch)).check(matches(isDisplayed()))
    onView(withId(R.id.speakerSwitch)).check(matches(isDisplayed()))
    onView(withId(R.id.cameraSwitch)).check(matches(isNotChecked()))
    onView(withId(R.id.micSwitch)).check(matches(isNotChecked()))
    onView(withId(R.id.speakerSwitch)).check(matches(isNotChecked()))
  }

  @Test
  fun speakerToggleWorksAfterPairAndUnpairResetsStatus() {
    scenarioRule.scenario.onActivity { activity ->
      AppPrefs.setPaired(activity, true)
      AppPrefs.setHostBaseUrl(activity, "http://127.0.0.1:8787")
      AppPrefs.setHostPairCode(activity, "PAIR-TEST")
    }
    scenarioRule.scenario.recreate()

    onView(withId(R.id.statusText)).check(
      matches(
        anyOf(
          withText(R.string.status_connected),
          withText(R.string.status_connected_degraded),
        ),
      ),
    )

    onView(withId(R.id.speakerSwitch)).perform(click())
    onView(withId(R.id.speakerSwitch)).check(matches(isChecked()))

    onView(withId(R.id.pairButton)).perform(click())
    onView(withId(R.id.statusText)).check(matches(withText(R.string.status_disconnected)))
  }
}
