import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                PageHeader(title: "Profile")
                branding
                identityCard
                listeningTimeCard
                versionCard
                settingsButton
            }
            .padding(.horizontal, MusicfySpacing.page)
            .padding(.top, 8)
            .padding(.bottom, MusicfySpacing.page)
        }
        .scrollContentBackground(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
        #if DEBUG
        .onAppear { state.reportScreenshotReady("profile") }
        #endif
        .alert(alertTitle, isPresented: $showsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var branding: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(.title, weight: .bold))
                .foregroundStyle(MusicfyTheme.primary)
                .frame(width: 44, height: 44)
                .background(MusicfyTheme.selected, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            Text("Hello again,\nMusicfy Demo!")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(MusicfyTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            AnyLayout(dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))) {
                Circle()
                    .fill(MusicfyTheme.field)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(MusicfyTheme.secondary)
                    }
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("Generic demo avatar")

                VStack(alignment: .leading, spacing: 4) {
                    Text("ID CARD OF")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(MusicfyTheme.secondary)
                    Text("Demo Listener")
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(MusicfyTheme.primary)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    demoID
                    Text("DEMO PROFILE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MusicfyTheme.secondary)
                }
            } else {
                HStack {
                    demoID
                    Spacer()
                    Text("DEMO PROFILE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MusicfyTheme.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MusicfyTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var demoID: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEMO ID")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MusicfyTheme.secondary)
            Text("DEMO-0001")
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(MusicfyTheme.primary)
        }
    }

    private var listeningTimeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Listening Time")
                    .font(MusicfyTypography.cardTitle)
                    .foregroundStyle(MusicfyTheme.primary)
                Spacer()
                Image(systemName: "clock")
                    .foregroundStyle(MusicfyTheme.secondary)
                    .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 16) {
                    listeningMetric
                    Spacer(minLength: 8)
                    statsButton
                }
                VStack(alignment: .leading, spacing: 16) {
                    listeningMetric
                    statsButton
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MusicfyTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var listeningMetric: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("0h | 30m")
                .font(.system(.title, weight: .bold))
                .foregroundStyle(MusicfyTheme.primary)
                .monospacedDigit()
            Text("Total Listening time · demo")
                .font(MusicfyTypography.subtitle)
                .foregroundStyle(MusicfyTheme.secondary)
        }
    }

    private var statsButton: some View {
        Button {
            present("View Stats", "Listening statistics are demo-only and are not connected to personal listening data.")
        } label: {
            Text("View Stats")
                .font(.body.weight(.semibold))
                .foregroundStyle(MusicfyTheme.background)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(MusicfyTheme.primary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View demo listening statistics")
    }

    private var versionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Version")
                    .font(MusicfyTypography.cardTitle)
                    .foregroundStyle(MusicfyTheme.primary)
                Spacer()
                Text("UI Prototype")
                    .font(MusicfyTypography.subtitle)
                    .foregroundStyle(MusicfyTheme.secondary)
            }

            Button {
                present("About demo", "Musicfy Demo is a local UI prototype. It does not connect to providers or use personal data.")
            } label: {
                HStack {
                    Label("About demo", systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.body.weight(.medium))
                .foregroundStyle(MusicfyTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MusicfyTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var settingsButton: some View {
        Button {
            present("Settings", "Settings are unavailable in this UI prototype.")
        } label: {
            HStack {
                Label("Settings", systemImage: "gearshape")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .font(.body.weight(.medium))
            .foregroundStyle(MusicfyTheme.primary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .modifier(MusicfyGlass(radius: 18))
        }
        .buttonStyle(.plain)
    }

    private func present(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showsAlert = true
    }
}
