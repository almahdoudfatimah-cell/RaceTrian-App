import SwiftUI
import StoreKit
import Observation

@MainActor
@Observable
final class WatchAccessStore {
    static let productIDs = ["Perminium_Weekly", "Perminium_Yearly"]

    private(set) var email: String?
    private(set) var isPremium = false
    private(set) var products: [Product] = []
    var selectedProductID = "Perminium_Yearly"
    var isBusy = false
    var message: String?
    private(set) var hasLoadedProducts = false

    private let defaults = UserDefaults.standard

    /// Subscription reported by the paired iPhone; saved so the watch stays unlocked offline.
    private(set) var isPremiumOnPhone = false

    init() {
        email = defaults.string(forKey: "watch.account.email")
        isPremiumOnPhone = defaults.bool(forKey: "watch.phonePremium")
    }

    var isSignedIn: Bool {
        email != nil
    }

    /// The watch unlocks with its own subscription or the iPhone's.
    var hasAccess: Bool {
        isPremium || isPremiumOnPhone
    }

    /// Email of the account signed in on the iPhone, used to pre-fill the watch's sign-in form.
    private(set) var phoneEmail: String?

    /// Applies the iPhone's subscription so the user doesn't pay twice. The watch still shows
    /// its own Create Account / Sign In screens; the iPhone's email only pre-fills the form.
    func applyPhoneAccount(isPremium: Bool, email phoneEmail: String?) {
        isPremiumOnPhone = isPremium
        defaults.set(isPremium, forKey: "watch.phonePremium")
        self.phoneEmail = phoneEmail
    }

    var selectedProduct: Product? {
        products.first { $0.id == selectedProductID }
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func authenticate(email: String, password: String, confirmation: String?, isCreating: Bool) -> Bool {
        message = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            message = "Enter a valid email."
            return false
        }
        guard password.count >= 8 else {
            message = "Use at least 8 characters."
            return false
        }
        if isCreating, password != confirmation {
            message = "Passwords do not match."
            return false
        }

        self.email = normalizedEmail
        defaults.set(normalizedEmail, forKey: "watch.account.email")
        return true
    }

    func signOut() {
        email = nil
        defaults.removeObject(forKey: "watch.account.email")
    }

    func purchaseSelectedProduct() async {
        guard let product = selectedProduct else {
            message = "Plans are unavailable. Try again."
            await loadProducts()
            return
        }

        isBusy = true
        message = nil
        defer { isBusy = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "The purchase could not be verified."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                message = "Purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                message = "The purchase could not be completed."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isBusy = true
        message = nil
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium {
                message = "No active subscription was found."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    func reloadProducts() async {
        message = nil
        await loadProducts()
    }

    private func loadProducts() async {
        defer { hasLoadedProducts = true }
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            message = "Unable to load plans."
        }
    }

    private func refreshEntitlements() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                continue
            }
            hasActiveSubscription = true
        }

        isPremium = hasActiveSubscription
    }
}

struct WatchEntryRootView: View {
    let store: WatchAppStore
    let access: WatchAccessStore

    @State private var entryScreen: WatchEntryScreen = .slider

    var body: some View {
        Group {
            // Same order as the iPhone: slider → paywall → create account → home.
            if access.isSignedIn {
                ContentView(store: store, access: access)
            } else {
                switch entryScreen {
                case .slider:
                    WatchSliderView { entryScreen = .accountChoice }
                case .accountChoice:
                    // Paywall, with Create Account and Sign In available right below it.
                    WatchPaywallView(
                        access: access,
                        showSignIn: { entryScreen = .signIn },
                        showCreateAccount: { entryScreen = .createAccount }
                    )
                case .signIn:
                    WatchAuthenticationView(
                        access: access,
                        mode: .signIn,
                        onComplete: { entryScreen = .accountChoice },
                        onSwitchMode: { entryScreen = .createAccount },
                        onBack: { entryScreen = .accountChoice }
                    )
                case .createAccount:
                    WatchAuthenticationView(
                        access: access,
                        mode: .createAccount,
                        onComplete: { entryScreen = .accountChoice },
                        onSwitchMode: { entryScreen = .signIn },
                        onBack: { entryScreen = .accountChoice }
                    )
                }
            }
        }
        .tint(WatchEntryPalette.orange)
        .preferredColorScheme(.light)
        .task {
            await access.prepare()
        }
        .task {
            await access.listenForTransactions()
        }
    }
}

private enum WatchEntryScreen {
    case slider
    case accountChoice
    case signIn
    case createAccount
}

/// The same three plans the iPhone paywall offers. Prices come from StoreKit when
/// available and fall back to the iPhone's listed prices so the plans always show.
enum WatchDisplayPlan: String, CaseIterable, Identifiable {
    case freeTrial
    case weekly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeTrial: "Free Trial"
        case .weekly: "Weekly"
        case .yearly: "Yearly"
        }
    }

    var subtitle: String {
        switch self {
        case .freeTrial: "1 week free, then $18/week"
        case .weekly: "$18 per week"
        case .yearly: "$117.99 per year"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .freeTrial: "Free"
        case .weekly: "$18.00"
        case .yearly: "$117.99"
        }
    }

    var period: String {
        switch self {
        case .freeTrial: ""
        case .weekly: "/week"
        case .yearly: "/year"
        }
    }

    var badge: String? {
        switch self {
        case .freeTrial: "1 Week Free"
        case .weekly: nil
        case .yearly: "Best Value"
        }
    }

    /// The free trial starts the weekly subscription, like on the iPhone.
    var productID: String {
        switch self {
        case .freeTrial, .weekly: "Perminium_Weekly"
        case .yearly: "Perminium_Yearly"
        }
    }
}

struct WatchPaywallView: View {
    let access: WatchAccessStore
    let showSignIn: () -> Void
    let showCreateAccount: () -> Void

    @State private var selectedPlan: WatchDisplayPlan = .freeTrial

    var body: some View {
        ZStack {
            WatchEntryBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                WatchBrandHeader(
                    title: "RaceTrian Premium",
                    subtitle: "Your plan, progress, and workouts on your wrist."
                )

                VStack(alignment: .leading, spacing: 7) {
                    WatchFeatureRow(title: "Weekly & Monthly Plans", icon: "calendar.badge.clock")
                    WatchFeatureRow(title: "Weekend, Vacation & Travel", icon: "airplane")
                    WatchFeatureRow(title: "Train & Track", icon: "figure.run")
                    WatchFeatureRow(title: "Achievement Timer", icon: "stopwatch.fill")
                    WatchFeatureRow(title: "Year Race Vision", icon: "flag.checkered")
                    WatchFeatureRow(title: "Life Goals", icon: "target")
                    WatchFeatureRow(title: "Syncs with iPhone", icon: "iphone.and.arrow.forward")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    ForEach(WatchDisplayPlan.allCases) { plan in
                        WatchPlanCard(
                            plan: plan,
                            price: price(for: plan),
                            isSelected: selectedPlan == plan
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPlan = plan
                            }
                        }
                    }
                }

                if access.hasLoadedProducts && access.products.isEmpty {
                    // The App Store didn't return the products; let the user retry.
                    Button("Reload Plans") {
                        Task { await access.reloadProducts() }
                    }
                    .buttonStyle(WatchLinkButtonStyle())
                    .disabled(access.isBusy)
                }

                if let message = access.message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    access.selectedProductID = selectedPlan.productID
                    Task { await access.purchaseSelectedProduct() }
                } label: {
                    if access.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(selectedPlan == .freeTrial ? "Start Free Trial" : "Continue")
                    }
                }
                .buttonStyle(WatchPrimaryButtonStyle())
                .disabled(access.isBusy)

                // After the plans and Continue, like the iPhone paywall's account actions.
                if !access.isSignedIn {
                    Button("Create Account", action: showCreateAccount)
                        .buttonStyle(WatchTintedCapsuleButtonStyle())
                        .disabled(access.isBusy)

                    Button("Already have an account? Sign In", action: showSignIn)
                        .buttonStyle(WatchLinkButtonStyle())
                        .disabled(access.isBusy)
                }

                Button("Restore Purchases") {
                    Task { await access.restorePurchases() }
                }
                .buttonStyle(WatchLinkButtonStyle())
                .disabled(access.isBusy)
                }
                .padding(.horizontal, 8)
            }
        }
        .containerBackground(WatchTheme.paper, for: .navigation)
    }

    private func price(for plan: WatchDisplayPlan) -> String {
        guard plan != .freeTrial,
              let product = access.products.first(where: { $0.id == plan.productID }) else {
            return plan.fallbackPrice
        }
        return product.displayPrice
    }
}

/// Cream plan card with an orange radio and border when selected, like the iPhone `PlanCard`.
private struct WatchPlanCard: View {
    let plan: WatchDisplayPlan
    let price: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WatchTheme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    if let badge = plan.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WatchTheme.secondary, in: Capsule())
                    }
                    Text(plan.subtitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchTheme.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(price)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    if !plan.period.isEmpty {
                        Text(plan.period)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(WatchTheme.muted)
                    }
                }
            }
            .padding(10)
            .background(WatchTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WatchTheme.primary.opacity(isSelected ? 1 : 0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Intro slides shown before the paywall, mirroring the iPhone `SplashView`.
private struct WatchSliderView: View {
    let onComplete: () -> Void

    private let slides: [(icon: String, title: String, subtitle: String)] = [
        ("flag.checkered", "RaceTrian", "Plan your training. Track your progress."),
        ("calendar.badge.clock", "Smart Plans", "Your day, organized around what matters."),
        ("chart.line.uptrend.xyaxis", "Better Insights", "See the patterns behind your progress.")
    ]

    @State private var index = 0

    var body: some View {
        TabView(selection: $index) {
            ForEach(slides.indices, id: \.self) { i in
                ScrollView {
                    VStack(spacing: 8) {
                        Image(systemName: slides[i].icon)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(WatchTheme.primary.gradient, in: Circle())
                        Text(slides[i].title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(WatchTheme.ink)
                        Text(slides[i].subtitle)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(WatchTheme.muted)
                        Button(i == slides.count - 1 ? "Get Started" : "Next") {
                            if i == slides.count - 1 {
                                onComplete()
                            } else {
                                withAnimation { index = i + 1 }
                            }
                        }
                        .buttonStyle(WatchPrimaryButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                }
                // watchOS reads the page background from each page, not the TabView.
                .containerBackground(WatchTheme.paper, for: .tabView)
                .tag(i)
            }
        }
        .tabViewStyle(.verticalPage)
    }
}

/// One premium feature on the watch paywall.
private struct WatchFeatureRow: View {
    let title: LocalizedStringKey
    let icon: String

    var body: some View {
        Label {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.ink)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(WatchTheme.primary.gradient, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct WatchAccountChoiceView: View {
    let showSignIn: () -> Void
    let showCreateAccount: () -> Void

    var body: some View {
        ZStack {
            WatchEntryBackground()
                .ignoresSafeArea()

            // Scrolls so both actions stay reachable on the smallest watch sizes.
            ScrollView {
                VStack(spacing: 12) {
                    WatchBrandHeader(
                        title: "You're Premium",
                        subtitle: "Create an account or sign in to continue."
                    )

                    Button("Create Account", action: showCreateAccount)
                        .buttonStyle(WatchPrimaryButtonStyle())

                    Button("Sign In", action: showSignIn)
                        .buttonStyle(WatchSecondaryButtonStyle())
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

private enum WatchAuthenticationMode {
    case signIn
    case createAccount

    var title: String {
        switch self {
        case .signIn: "Welcome Back"
        case .createAccount: "Create Account"
        }
    }

    var buttonTitle: String {
        switch self {
        case .signIn: "Sign In"
        case .createAccount: "Create Account"
        }
    }

    var switchTitle: String {
        switch self {
        case .signIn: "No account? Create one"
        case .createAccount: "Have an account? Sign In"
        }
    }
}

private struct WatchAuthenticationView: View {
    let access: WatchAccessStore
    let mode: WatchAuthenticationMode
    let onComplete: () -> Void
    let onSwitchMode: () -> Void
    let onBack: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        ZStack {
            WatchEntryBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                WatchBrandHeader(
                    title: mode.title,
                    subtitle: "Keep your training connected."
                )

                TextField("Email", text: $email, prompt: WatchEntryPalette.prompt("Email"))
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .watchEntryFieldStyle()

                SecureField("Password", text: $password, prompt: WatchEntryPalette.prompt("Password"))
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .watchEntryFieldStyle()

                if mode == .createAccount {
                    SecureField("Confirm Password", text: $confirmation, prompt: WatchEntryPalette.prompt("Confirm Password"))
                        .textContentType(.newPassword)
                        .watchEntryFieldStyle()
                }

                if let message = access.message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(mode.buttonTitle) {
                    let succeeded = access.authenticate(
                        email: email,
                        password: password,
                        confirmation: mode == .createAccount ? confirmation : nil,
                        isCreating: mode == .createAccount
                    )
                    if succeeded {
                        onComplete()
                    }
                }
                .buttonStyle(WatchPrimaryButtonStyle())

                Button(mode.switchTitle, action: onSwitchMode)
                    .buttonStyle(WatchLinkButtonStyle())

                Button("Back", action: onBack)
                    .buttonStyle(WatchSecondaryButtonStyle())
                }
                .padding(.horizontal, 8)
            }
        }
        .onAppear {
            // Don't carry errors from the paywall or the other form onto this page.
            access.message = nil
            if email.isEmpty, let phoneEmail = access.phoneEmail {
                email = phoneEmail
            }
        }
    }
}

private struct WatchBrandHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(WatchTheme.primary)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(WatchTheme.ink)
            Text(subtitle)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(WatchTheme.muted)
        }
    }
}

/// Flat cream page background, matching the home page's container background.
private struct WatchEntryBackground: View {
    var body: some View {
        WatchTheme.paper
    }
}

/// Entry screens reuse the shared `WatchTheme` colours so they match the home page.
private enum WatchEntryPalette {
    static let orange = WatchTheme.primary
    static let ink = WatchTheme.ink
    static let muted = WatchTheme.muted

    /// Placeholder text that stays legible on the light field background.
    static func prompt(_ title: String) -> Text {
        Text(title).foregroundStyle(muted)
    }
}

/// Orange rounded button matching the home page's primary actions.
private struct WatchPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                WatchTheme.primary.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Cream card with orange text and border, matching the home page's secondary cards.
private struct WatchSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(WatchTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                WatchTheme.cardSurface.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WatchTheme.primary.opacity(0.35), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Light-orange capsule with orange text, matching the iPhone paywall's Create Account button.
private struct WatchTintedCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(WatchTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(WatchTheme.primary.opacity(configuration.isPressed ? 0.2 : 0.12), in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Borderless orange text for small links, replacing watchOS's default gray capsule.
private struct WatchLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(WatchTheme.primary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : (isEnabled ? 1 : 0.4))
    }
}

private extension View {
    /// Text fields sit in cream cards with dark text and an orange caret.
    func watchEntryFieldStyle() -> some View {
        self
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(WatchEntryPalette.ink)
            .tint(WatchEntryPalette.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WatchTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview("Paywall") {
    WatchPaywallView(access: WatchAccessStore(), showSignIn: {}, showCreateAccount: {})
}
