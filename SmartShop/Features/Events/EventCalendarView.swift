//
//  EventCalendarView.swift
//  SmartShop
//

import SwiftUI

/// Month calendar with free and ticketed events. Port of `EventCalendar.tsx`.
struct EventCalendarView: View {
    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages
    @Environment(AppEnvironment.self) private var environment

    @State private var cursor: Date = Self.month(of: .now)
    /// Upcoming events from `eventService`, each carrying the customer's own
    /// ticket. Starts empty rather than on the bundled list: a bundled event
    /// has an id the server has never issued, so a seat taken on it would 404.
    @State private var events: [AppEvent] = []
    /// Once the customer has paged, loading must not yank them back.
    @State private var hasMoved = false
    @State private var selected: String?
    @State private var buying: String?
    @State private var error: String?

    private var locale: Locale { languages.language.locale }
    private var calendar: Calendar { var c = Calendar(identifier: .iso8601); c.locale = locale; return c }

    private var monthPrefix: String {
        let c = calendar.dateComponents([.year, .month], from: cursor)
        return String(format: "%04d-%02d", c.year!, c.month!)
    }
    private var monthEvents: [AppEvent] { events.filter { $0.date.hasPrefix(monthPrefix) } }
    private var shown: [AppEvent] { selected.map { day in monthEvents.filter { $0.date == day } } ?? monthEvents }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                navButton("chevron.left", label: t("events.prevMonth")) { move(-1) }
                Spacer()
                Text(cursor.formatted(Date.FormatStyle().month(.wide).year().locale(locale)))
                    .font(Theme.display(.title3, weight: .heavy)).foregroundStyle(Theme.Colors.green)
                Spacer()
                navButton("chevron.right", label: t("events.nextMonth")) { move(1) }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(t("events.weekdays.\(i)"))
                        .font(Theme.body(.caption2, weight: .semibold)).textCase(.uppercase)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(Theme.Colors.green.opacity(0.5))
                }
            }
            .padding(.top, Theme.Spacing.md)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(1...daysInMonth, id: \.self) { day in
                    let iso = monthPrefix + String(format: "-%02d", day)
                    let has = monthEvents.contains { $0.date == iso }
                    let isSelected = selected == iso
                    let isToday = iso == todayIso
                    Button {
                        selected = isSelected ? nil : iso
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(day)").font(Theme.body(.subheadline, weight: .semibold))
                            if has {
                                Circle().fill(isSelected ? Theme.Colors.lime : Theme.Colors.green).frame(width: 6, height: 6)
                            }
                        }
                        .foregroundStyle(isSelected ? .white : has ? Theme.Colors.green : Theme.Colors.green.opacity(0.4))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isSelected ? Theme.Colors.green : has ? Theme.Colors.lime.opacity(0.2) : .clear, in: .rect(cornerRadius: Theme.Radius.field))
                        .overlay {
                            if isToday && !isSelected {
                                RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.lime, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!has)
                }
            }
            .padding(.top, 4)

            Text(selected == nil ? t("events.upcoming") : t("events.eventsOnDay"))
                .font(Theme.display(.subheadline, weight: .bold)).textCase(.uppercase).tracking(0.8)
                .foregroundStyle(Theme.Colors.green.opacity(0.6))
                .padding(.top, Theme.Spacing.lg).padding(.bottom, 12)

            if shown.isEmpty {
                Text(t("events.noEvents")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.6))
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(shown) { event in eventCard(event) }
                }
            }

            if let error {
                Text(error).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red).padding(.top, 12)
            }

            DemoNote(badge: t("events.demoBadge"), text: t("events.demoNote")).padding(.top, 20)
        }
        .task { await load() }
    }

    private func load() async {
        do {
            events = try await environment.eventService.events()
            // Open on the month of the next event, as the bundled calendar did.
            if !hasMoved, let first = events.first?.day { cursor = Self.month(of: first) }
        } catch {
            if events.isEmpty { self.error = t("events.loadError") }
        }
    }

    private static func month(of date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private var todayIso: String {
        let c = calendar.dateComponents([.year, .month, .day], from: .now)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: cursor)?.count ?? 30 }
    /// Monday-first offset of the 1st.
    private var leadingBlanks: Int { (calendar.component(.weekday, from: cursor) + 5) % 7 }

    private func move(_ months: Int) {
        hasMoved = true
        selected = nil
        cursor = calendar.date(byAdding: .month, value: months, to: cursor) ?? cursor
    }

    private func navButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .rotationEffect(.degrees(8)).frame(width: 56, height: 40)
                .background(Theme.Colors.green, in: .ellipse)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func eventCard(_ event: AppEvent) -> some View {
        let lang = languages.language
        let ticket = event.myTicket.flatMap { $0.isHeld ? $0 : nil }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(event.day?.formatted(Date.FormatStyle(date: .long).locale(locale)) ?? event.date, systemImage: "calendar")
                    .font(Theme.body(.caption, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5).background(Theme.Colors.green, in: .capsule)
                Text(event.priceKr == 0 ? t("events.free") : "\(t("events.price")): \(event.priceKr) kr.")
                    .font(Theme.body(.caption, weight: .bold))
                    .foregroundStyle(event.priceKr == 0 ? .white : Theme.Colors.green)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(event.priceKr == 0 ? Theme.Colors.lime : Theme.Colors.lime.opacity(0.2), in: .capsule)
            }
            Text(event.title(lang)).font(Theme.display(.title3, weight: .heavy)).foregroundStyle(Theme.Colors.green)
            Text(event.body(lang)).font(Theme.body(.subheadline)).lineSpacing(3).foregroundStyle(Theme.Colors.green.opacity(0.7))
            HStack(spacing: 16) {
                Label(event.time, systemImage: "clock")
                Label(event.place(lang), systemImage: "mappin.and.ellipse")
            }
            .font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.6))

            if event.priceKr > 0 {
                if let ticket {
                    ticketBox(ticket)
                } else if event.soldOut {
                    Label(t("events.soldOut"), systemImage: "xmark.circle")
                        .font(Theme.display(.subheadline, weight: .bold)).foregroundStyle(Theme.Colors.green.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.green.opacity(0.05), in: .rect(cornerRadius: Theme.Radius.field))
                } else {
                    Button {
                        Task { await buy(event) }
                    } label: {
                        Label(buying == event.id ? t("events.buying") : "\(t("events.buyTicket")) · \(event.priceKr) kr.", systemImage: "ticket")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                    .disabled(buying == event.id)
                }
            }
        }
        .padding(20)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay { RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Colors.green.opacity(0.1)) }
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    /// A paid seat is only held until it is paid for at the till, so it must
    /// never read as bought. See `EventTicket`.
    private func ticketBox(_ ticket: EventTicket) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if ticket.isAwaitingPayment {
                Label(t("events.ticketReserved"), systemImage: "clock")
                    .font(Theme.display(.subheadline, weight: .bold)).foregroundStyle(Theme.Colors.green)
                Text(reservedNote(ticket)).font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.7))
            } else {
                Label(t("events.ticketBought"), systemImage: "ticket")
                    .font(Theme.display(.subheadline, weight: .bold)).foregroundStyle(Theme.Colors.green)
                Text(t("events.ticketBoughtNote")).font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.7))
            }
            if let code = ticket.code {
                Text("\(t("events.ticketCode")): \(code)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.Colors.green)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.Colors.lime.opacity(0.15), in: .rect(cornerRadius: Theme.Radius.field))
    }

    private func reservedNote(_ ticket: EventTicket) -> String {
        guard let expiresAt = ticket.expiresAt else { return t("events.ticketReservedNoDeadline") }
        let time = expiresAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
        return t("events.ticketReservedNote").replacingOccurrences(of: "{time}", with: time)
    }

    private func buy(_ event: AppEvent) async {
        error = nil
        buying = event.id
        defer { buying = nil }
        do {
            let ticket = try await environment.eventService.takeSeat(at: event)
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].myTicket = ticket
            }
        } catch {
            // A 409 is "sold out" or "you already hold one"; re-reading shows
            // whichever it was, rather than a generic failure on a held seat.
            self.error = t("events.buyError")
        }
        // Seats left moved either way.
        await load()
        if events.first(where: { $0.id == event.id })?.myTicket?.isHeld == true { error = nil }
    }
}
