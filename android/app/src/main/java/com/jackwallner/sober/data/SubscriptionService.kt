package com.jackwallner.sober.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sober.BuildConfig
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PeriodType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.syncPurchasesWith
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.paywalls.events.CustomPaywallImpressionParams
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.delay

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

enum class OnboardingTrialResolution { ELIGIBLE, INELIGIBLE, UNAVAILABLE, FAILED }

internal fun purchaseOutcome(code: PurchasesErrorCode, userCancelled: Boolean): PurchaseOutcome? = when {
    userCancelled || code == PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.CANCELLED
    code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.PENDING
    else -> null
}

internal fun restoreFailureMessage(code: PurchasesErrorCode): String =
    if (code == PurchasesErrorCode.PaymentPendingError) {
        "Google Play is still processing your payment. Bloom+ unlocks as soon as it completes."
    } else "Couldn't restore purchases. Try again."

internal fun managedSubscriptionId(activeSubscriptions: Set<String>): String? =
    activeSubscriptions.map { it.substringBefore(":") }.sorted().firstOrNull()

private fun Period.toPlanPeriod(): PlanPeriod? {
    val unit = when (unit) {
        Period.Unit.DAY -> PeriodUnit.DAY
        Period.Unit.WEEK -> PeriodUnit.WEEK
        Period.Unit.MONTH -> PeriodUnit.MONTH
        Period.Unit.YEAR -> PeriodUnit.YEAR
        else -> return null
    }
    return PlanPeriod(value, unit)
}

class PurchaseException(message: String) : Exception(message)

/**
 * RevenueCat behind the single `pro` entitlement, shown as Bloom+. Debug
 * builds use the Test Store key and release builds the Play key; neither ever
 * runs on the other. The paywall reads every price and trial from the store.
 */
class SubscriptionService(
    private val context: Context,
    private val defaults: KeyValueStore,
    private val diagnostics: ConversionDiagnostics,
    private val trial: TrialLifecycle,
) {
    private val reviewAccess = ReviewAccess(defaults, BuildConfig.PLAY_REVIEW_CODE_SHA256)
    private var entitlementActive by mutableStateOf(false)
    private var overrideActive by mutableStateOf(BuildConfig.DEBUG && defaults.getBoolean(LOCAL_OVERRIDE))
    private var reviewGranted by mutableStateOf(reviewAccess.isGranted)
    private var forcePro by mutableStateOf(false)

    /** The single gate the whole app reads. */
    val isPro: Boolean get() = entitlementActive || overrideActive || reviewGranted || forcePro

    var isConfigured by mutableStateOf(false)
        private set
    var isLoadingProducts by mutableStateOf(false)
        private set
    var lastError by mutableStateOf<String?>(null)
        private set
    var packages by mutableStateOf<List<Package>>(emptyList())
        private set
    var plans by mutableStateOf<List<Plan>>(emptyList())
        private set
    var hasSubscriptionHistory by mutableStateOf(false)
        private set
    /** Until customer info has answered, never promise a trial (it may already be used). */
    var introEligibilityResolved by mutableStateOf(false)
        private set
    var activeProductId by mutableStateOf<String?>(null)
        private set

    private var offering: Offering? = null
    private var customerInfoLoaded = false
    private var subscriptionHistoryOverride: Boolean? = null
    private val impressionsThisSession = mutableSetOf<String>()

    /** The legacy complimentary trial; never granted on Android. */
    val hasClaimedTrial: Boolean get() = defaults.getBoolean("bloomTrialClaimed")

    // MARK: - Debug and review access

    fun forceProForDebug(value: Boolean = true) {
        if (!BuildConfig.DEBUG) return
        forcePro = value
    }

    fun setLocalOverride(value: Boolean) {
        if (!BuildConfig.DEBUG) return
        defaults.putBoolean(LOCAL_OVERRIDE, value)
        overrideActive = value
    }

    fun setSubscriptionHistoryForDebug(value: Boolean) {
        if (!BuildConfig.DEBUG) return
        subscriptionHistoryOverride = value
        hasSubscriptionHistory = value
    }

    /** Debug screenshots and UI tests: a local plan stack with no store behind it. */
    fun loadPreviewPlans(plans: List<Plan>, history: Boolean = false) {
        if (!BuildConfig.DEBUG) return
        this.plans = plans
        packages = emptyList()
        hasSubscriptionHistory = history
        introEligibilityResolved = true
        isConfigured = true
        isPreview = true
        lastError = null
    }

    private var isPreview = false

    fun activateReviewAccess(code: String): Boolean {
        if (!reviewAccess.activate(code)) return false
        reviewGranted = true
        return true
    }

    // MARK: - Store

    suspend fun start() {
        if (!configureIfNeeded()) return
        refreshCustomerInfo()
        fetchProducts()
    }

    suspend fun refreshCustomerInfo() {
        if (!configureIfNeeded() || isPreview) return
        runCatching { Purchases.sharedInstance.awaitCustomerInfo() }
            .onSuccess(::apply)
            .onFailure { if (it is CancellationException) throw it }
    }

    suspend fun fetchProducts() {
        if (!configureIfNeeded() || isPreview) return
        if (isLoadingProducts) {
            while (isLoadingProducts) delay(50)
            return
        }
        isLoadingProducts = true
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            val offering: Offering? = offerings.all[ANDROID_OFFERING_ID] ?: offerings.current
            val loaded = offering?.availablePackages.orEmpty().sortedWith(
                compareBy<Package> { kind(it).ordinal }.thenBy { it.product.id },
            )
            this.offering = offering
            packages = loaded
            plans = loaded.map(::plan)
            lastError = if (loaded.isEmpty()) "Plans are temporarily unavailable. Please try again in a moment." else null
            if (!customerInfoLoaded) refreshCustomerInfo()
            introEligibilityResolved = customerInfoLoaded
        } catch (error: CancellationException) {
            throw error
        } catch (_: Throwable) {
            packages = emptyList()
            plans = emptyList()
            lastError = "Couldn't load subscription options. Check your connection and try again."
        } finally {
            isLoadingProducts = false
        }
    }

    fun isEligibleForIntroOffer(plan: Plan): Boolean =
        plan.trial != null && introEligibilityResolved && !hasSubscriptionHistory

    val hasTrialOfferAvailable: Boolean get() = plans.any(::isEligibleForIntroOffer)

    /** The plan the one-tap onboarding trial buys: yearly first, monthly as fallback. */
    val directTrialPlan: Plan? get() = preferredTrialPlan(plans.filter(::isEligibleForIntroOffer))

    /** What the onboarding CTA buys, trial or not. */
    val directOfferPlan: Plan? get() = directTrialPlan ?: preferredTrialPlan(plans)

    val trialOfferDayCount: Int? get() = directTrialPlan?.trial?.days

    /** "7-day free trial, then $29.99 / year." or the price alone. */
    val directTrialPriceHeadline: String?
        get() {
            val plan = directOfferPlan ?: return null
            val label = plan.introOfferLabel
            return if (isEligibleForIntroOffer(plan) && label != null) "${label.capitalizeWords()}, then ${plan.priceLabel}."
            else "${plan.priceLabel}."
        }

    val directTrialRenewalDisclosure: String? get() = if (directTrialPriceHeadline == null) null else AUTO_RENEW_DISCLOSURE

    suspend fun resolveOnboardingTrial(): OnboardingTrialResolution {
        if (isPro) return OnboardingTrialResolution.INELIGIBLE
        if (plans.isEmpty() || !introEligibilityResolved || lastError != null) fetchProducts()
        if (isPro) return OnboardingTrialResolution.INELIGIBLE
        if (plans.isEmpty()) return if (lastError == null) OnboardingTrialResolution.UNAVAILABLE else OnboardingTrialResolution.FAILED
        val trialPlans = plans.filter { it.trial != null }
        if (trialPlans.isEmpty()) return OnboardingTrialResolution.UNAVAILABLE
        if (!introEligibilityResolved) return OnboardingTrialResolution.FAILED
        if (preferredTrialPlan(trialPlans.filter(::isEligibleForIntroOffer)) != null) return OnboardingTrialResolution.ELIGIBLE
        return OnboardingTrialResolution.INELIGIBLE
    }

    /** Feeds RevenueCat's paywall encounters; a custom paywall emits none of its own. */
    fun trackPaywallImpression(id: String, oncePerSession: Boolean = false) {
        if (oncePerSession && !impressionsThisSession.add(id)) return
        diagnostics.recordPitchView(id)
        if (!isConfigured || isPreview) return
        syncConversionAttributes()
        val params = offering?.let { CustomPaywallImpressionParams(id, it) } ?: CustomPaywallImpressionParams(id)
        runCatching { Purchases.sharedInstance.trackCustomPaywallImpression(params) }
    }

    /** `funnel_*` event counters plus the fleet-wide paywall keys, as on iOS. */
    fun syncConversionAttributes() {
        if (!isConfigured || isPreview) return
        val attributes = mutableMapOf<String, String>()
        diagnostics.counts.forEach { (event, count) -> attributes["funnel_${event.key}"] = count.toString() }
        attributes.putAll(diagnostics.subscriberAttributes)
        if (attributes.isEmpty()) return
        runCatching { Purchases.sharedInstance.setAttributes(attributes) }
    }

    /** A cancel is an outcome, not an error. Throws only with a user-facing message. */
    suspend fun purchase(activity: Activity, plan: Plan?): PurchaseOutcome {
        if (isPreview && plan != null) {
            setLocalOverride(true)
            return PurchaseOutcome.PURCHASED
        }
        val pkg = plan?.let { p -> packages.firstOrNull { it.identifier == p.packageId } }
        if (!configureIfNeeded() || pkg == null) throw PurchaseException(UNAVAILABLE)
        val startedTrial = isEligibleForIntroOffer(plan)
        val option = if (startedTrial) pkg.product.defaultOption else pkg.product.subscriptionOptions?.basePlan
        val params = if (option != null) {
            PurchaseParams.Builder(activity, option).presentedOfferingContext(pkg.presentedOfferingContext).build()
        } else PurchaseParams.Builder(activity, pkg).build()
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(params)
            apply(result.customerInfo)
            if (!entitlementActive) return PurchaseOutcome.PENDING
            diagnostics.recordConversion(pkg.product.id, startedTrial, pkg.presentedOfferingContext.offeringIdentifier)
            syncConversionAttributes()
            PurchaseOutcome.PURCHASED
        } catch (error: PurchasesTransactionException) {
            purchaseOutcome(error.code, error.userCancelled)
                ?: throw PurchaseException("Couldn't complete the purchase. Please try again.")
        }
    }

    /** Play says the money moved; the entitlement can take a beat to catch up. */
    suspend fun confirmEntitlement(attempts: Int = 3): Boolean {
        if (!isConfigured) return isPro
        repeat(attempts) { attempt ->
            refreshCustomerInfo()
            if (isPro) return true
            if (attempt < attempts - 1) delay(1_200)
        }
        return isPro
    }

    /** Leaves `lastError` set when nothing was restored, like iOS. */
    suspend fun restorePurchases() {
        lastError = null
        if (isPreview) return
        if (!configureIfNeeded()) {
            lastError = UNAVAILABLE
            return
        }
        try {
            apply(Purchases.sharedInstance.awaitRestore())
            if (!entitlementActive) lastError = "No active Bloom+ purchase was found for this Google Play account."
        } catch (error: CancellationException) {
            throw error
        } catch (error: PurchasesException) {
            lastError = restoreFailureMessage(error.code)
        } catch (_: Throwable) {
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    private fun apply(info: CustomerInfo) {
        customerInfoLoaded = true
        hasSubscriptionHistory = subscriptionHistoryOverride ?: info.allExpirationDatesByProduct.isNotEmpty()
        introEligibilityResolved = plans.isNotEmpty() || packages.isNotEmpty()
        val entitlement = info.entitlements[ENTITLEMENT] ?: info.entitlements.active.values.firstOrNull()
        entitlementActive = info.entitlements[ENTITLEMENT]?.isActive == true || info.entitlements.active.isNotEmpty()
        activeProductId = managedSubscriptionId(info.activeSubscriptions)
        trial.sync(
            isTrialing = entitlement?.isActive == true && entitlement.periodType == PeriodType.TRIAL,
            endsAt = entitlement?.expirationDate?.time,
        )
    }

    private fun configureIfNeeded(): Boolean {
        if (isConfigured) return true
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return false
        // Never the production Play key in a debug build, and never a test key in release.
        if (BuildConfig.DEBUG && key.startsWith("goog_")) return false
        if (!BuildConfig.DEBUG && !key.startsWith("goog_")) return false
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        val builder = PurchasesConfiguration.Builder(context, key)
        // Test Store runs share one tester instead of a fresh anonymous customer
        // per install, so test runs don't inflate the live project's New and
        // Active Customers. Never with the Play key: real buyers would share one
        // identity.
        if (key.startsWith("test_")) builder.appUserID(QA_APP_USER_ID)
        Purchases.configure(builder.build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        // The Play app moved into the iOS app's RevenueCat project on 2026-10-27.
        // Post this install's Play purchases there once, so a trial or purchase
        // made under the old Android-only project keeps its access.
        if (key.startsWith("goog_") && !defaults.getBoolean(SYNCED_TO_SHARED_PROJECT)) {
            Purchases.sharedInstance.syncPurchasesWith(onError = {}) {
                defaults.putBoolean(SYNCED_TO_SHARED_PROJECT, true)
                apply(it)
            }
        }
        isConfigured = true
        return true
    }

    private fun kind(pkg: Package): PackageKind = when (pkg.packageType) {
        PackageType.LIFETIME -> PackageKind.LIFETIME
        PackageType.ANNUAL -> PackageKind.YEARLY
        PackageType.MONTHLY -> PackageKind.MONTHLY
        else -> PackageKind.fromIdentifiers(pkg.identifier, pkg.product.id)
    }

    private fun plan(pkg: Package): Plan {
        val price = pkg.product.price
        val free = pkg.product.subscriptionOptions?.firstOrNull { it.freePhase != null }?.freePhase
            ?: pkg.product.defaultOption?.freePhase
        return Plan(
            packageId = pkg.identifier,
            productId = pkg.product.id,
            kind = kind(pkg),
            priceMicros = price.amountMicros,
            priceFormatted = price.formatted,
            currencyCode = price.currencyCode,
            period = pkg.product.period?.toPlanPeriod(),
            trial = free?.billingPeriod?.toPlanPeriod(),
            title = pkg.product.title,
        )
    }

    companion object {
        private const val QA_APP_USER_ID = "qa-android"
        private const val SYNCED_TO_SHARED_PROJECT = "subscription.syncedToSharedProject"
        const val ENTITLEMENT = "Sober Tracker - Alcohol Free Pro"
        private const val ANDROID_OFFERING_ID = "android"
        private const val LOCAL_OVERRIDE = "subscription.localProOverride"
        private const val UNAVAILABLE = "Google Play isn't reachable right now. Check your connection and try again."

        const val AUTO_RENEW_DISCLOSURE = "Auto-renews unless cancelled before the end of the current period. Manage or cancel in Google Play › Payments & subscriptions."

        fun preferredTrialPlan(candidates: List<Plan>): Plan? {
            val kinds = candidates.map { it.kind }
            val preferred = when {
                PackageKind.YEARLY in kinds -> PackageKind.YEARLY
                PackageKind.MONTHLY in kinds -> PackageKind.MONTHLY
                else -> kinds.firstOrNull()
            } ?: return null
            return candidates.firstOrNull { it.kind == preferred }
        }
    }
}

internal fun String.capitalizeWords(): String =
    split(" ").joinToString(" ") { word -> word.split("-").joinToString("-") { it.replaceFirstChar(Char::uppercaseChar) } }
