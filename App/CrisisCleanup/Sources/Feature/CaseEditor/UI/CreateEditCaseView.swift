//  Created by Anthony Aguilar on 7/6/23.

import SwiftUI
import MapKit
import FlowStackLayout

struct CreateEditCaseView: View {
    @ObservedObject var viewModel: CreateEditCaseViewModel

    @ObservedObject private var focusableViewState = TextInputFocusableView()

    @State private var showBusyIndicator = true

    var body: some View {
        ZStack {
            CreateEditCaseContentView()

            if showBusyIndicator {
                ProgressView()
            }

            if viewModel.showExplainLocationPermission {
                LocationAppSettingsDialog {
                    viewModel.showExplainLocationPermission = false
                }
            }
        }
        .screenTitle(viewModel.headerTitle)
        .hideNavBarUnderSpace()
        .onChange(of: viewModel.areEditorsReady) { isReady in
            withAnimation {
                showBusyIndicator = !isReady
            }
        }
        .onAppear { viewModel.onViewAppear() }
        .onDisappear { viewModel.onViewDisappear() }
        .environmentObject(viewModel)
        .environmentObject(viewModel.editableViewState)
        .environmentObject(focusableViewState)
    }
}

private struct CreateEditCaseContentView: View {
    @EnvironmentObject var viewModel: CreateEditCaseViewModel
    @EnvironmentObject private var focusableViewState: TextInputFocusableView

    @State var sectionCollapse = [
        false,
        false,
        false,
        false,
        false
    ]

    var body: some View {
        let disableMutation = viewModel.editableViewState.disabled
        let editSections = viewModel.editSections

        VStack {
            ScrollViewReader { proxy in
                FocusSectionSlider(
                    sectionTitles: editSections,
                    proxy: proxy
                )
                // TODO: Common dimensions
                .padding(.vertical, 8)

                ScrollView {
                    VStack {
                        if let caseState = viewModel.caseData {
                            HStack{
                                CaseIncidentView(
                                    incident: caseState.incident,
                                    isPendingSync: caseState.isPendingSync,
                                    isSyncing: viewModel.isSyncing,
                                    scheduleSync: { viewModel.scheduleSync() }
                                )
                                .padding()
                            }
                        }

                        Group {
                            CreateEditCaseSectionHeaderView (
                                isCollapsed: $sectionCollapse[0],
                                titleNumber: 1,
                                titleTranslateKey: editSections.get(0, "")
                            )
                            .id("section0")

                            if !sectionCollapse[0] {
                                PropertyInformation(
                                    propertyData: viewModel.propertyInputData,
                                    locationData: viewModel.locationInputData
                                )
                            }
                        }
                        .onScrollSectionFocus(
                            proxy,
                            scrollToId: "scrollBar0"
                        )

                        let nodes = Array(viewModel.groupFormFieldNodes.enumerated())
                        ForEach(nodes, id: \.offset) { offset, node in
                            FormListSectionSeparator()

                            let sectionIndex = offset + 1
                            Group {
                                CreateEditCaseSectionHeaderView (
                                    isCollapsed: $sectionCollapse[sectionIndex],
                                    titleNumber: sectionIndex + 1,
                                    titleTranslateKey: editSections.get(sectionIndex, ""),
                                    helpText: node.formField.help
                                )
                                .id("section\(sectionIndex)")

                                VStack {
                                    if !sectionCollapse[sectionIndex] {
                                        let children = node.children
                                            .filter { !ignoreFormFieldKeys.contains($0.fieldKey) }
                                        ForEach(children, id: \.id) { child in
                                            if child.parentKey == node.fieldKey {
                                                DisplayFormField(
                                                    checkedData: $viewModel.binaryFormData,
                                                    contentData: $viewModel.contentFormData,
                                                    node: child
                                                )
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            }
                            .onScrollSectionFocus(
                                proxy,
                                scrollToId: "scrollBar\(sectionIndex)"
                            )
                        }
                    }
                }
                .coordinateSpace(name: "scrollForm")
                .scrollDismissesKeyboard(.immediately)
            }

            if focusableViewState.isFocused {
                OpenKeyboardActionsView()
            } else {
                CreateEditCaseSaveActions()
                    .disabled(disableMutation)
            }
        }
    }
}

private func collapseIconName(_ isCollapsed: Bool) -> String {
    isCollapsed ? "chevron.up" : "chevron.down"
}

private struct CreateEditCaseSectionHeaderView: View {
    @Environment(\.translator) var t: KeyAssetTranslator

    @Binding var isCollapsed: Bool

    let titleNumber: Int
    let titleTranslateKey: String
    var helpText = ""

    var body: some View {
        HStack {
            Button {
                isCollapsed.toggle()
            } label: {
                ViewCaseRowHeader(rowNum: titleNumber, rowTitle: t.t(titleTranslateKey))

                if helpText.isNotBlank {
                    HelpIcon(helpText)
                        .padding(.horizontal)
                }

                Spacer()

                Image(systemName: collapseIconName(isCollapsed))
            }
        }
        .padding()
        .tint(.black)
    }
}

private struct ErrorTextView: View {
    let text: String
    var paddingEdges: Edge.Set = []

    var body: some View {
        if text.isNotBlank {
            Text(text)
                .fontHeader3()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(appTheme.colors.primaryRedColor)
                .padding(paddingEdges)
        }
    }
}

struct PropertyInformation: View {
    @Environment(\.translator) var t: KeyAssetTranslator

    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var viewModel: CreateEditCaseViewModel
    @EnvironmentObject var editableView: EditableView
    @EnvironmentObject var focusableViewState: TextInputFocusableView
    @EnvironmentObject var locationManager: LocationManager

    @ObservedObject var propertyData: PropertyInputData
    @ObservedObject var locationData: LocationInputData

    @FocusState private var focusState: TextInputFocused?

    @State private var map = MKMapView()

    @State private var fullAddressPlaceholder: String = ""

    var body: some View {
        let disabled = editableView.disabled
        VStack(alignment: .leading) {
            Group {
                ErrorTextView(text: propertyData.residentNameError)
                TextField(t.t("formLabels.name"), text: $propertyData.residentName)
                    .focused($focusState, equals: .caseInfoName)
                    .textFieldBorder()
                    .disabled(disabled)
                    .padding(.bottom)

                ErrorTextView(text: propertyData.phoneNumberError)
                TextField(t.t("formLabels.phone1"), text: $propertyData.phoneNumber)
                    .focused($focusState, equals: .caseInfoPhone)
                    .textFieldBorder()
                    .disabled(disabled)
                    .padding(.bottom)

                TextField(t.t("formLabels.phone2"), text: $propertyData.phoneNumberSecondary)
                    .focused($focusState, equals: .anyTextInput)
                    .textFieldBorder()
                    .disabled(disabled)
                    .padding(.bottom)

                ErrorTextView(text: propertyData.emailError)
                TextField(t.t("formLabels.email"), text: $propertyData.email)
                    .keyboardType(.emailAddress)
                    .focused($focusState, equals: .caseInfoEmail)
                    .textFieldBorder()
                    .disabled(disabled)
                    .padding(.bottom)
            }
            .padding(.horizontal)

            VStack(alignment: .leading) {
                Text(t.t("casesVue.auto_contact_frequency"))
                    .listItemPadding()

                ForEach(autoContactFrequencyOptions, id: \.self) { option in
                    RadioButton(
                        text: t.t(option.literal),
                        isSelected: option == propertyData.autoContactFrequency,
                        nestedLevel: 1,
                        isListItem: true
                    ) {
                        propertyData.autoContactFrequency = option
                    }
                }
                .disabled(disabled)
            }

            Text(t.t("formLabels.location"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading)

            if viewModel.isOnline && locationData.isSearchSuggested {
                TextField(
                    t.t("caseView.full_address"),
                    text: $fullAddressPlaceholder,
                    onEditingChanged: { focus in
                        if focus {
                            router.openCaseSearchLocation()
                        }
                    }
                )
                .textFieldBorder()
                .disabled(disabled)
                .padding(.horizontal)
            }

            let outOfBoundsMessage = viewModel.locationOutOfBoundsMessage
            CreateEditCaseMapView(
                map: $map,
                caseCoordinates: $viewModel.mapCoordinates,
                isCreateWorksite: viewModel.isCreateWorksite
            )
            .if(viewModel.areEditorsReady && outOfBoundsMessage.isNotBlank) { view in
                view.overlay(alignment: .bottomLeading) {
                    Text(outOfBoundsMessage)
                        .fontBodySmall()
                        .padding()
                        .background(.white.disabledAlpha())
                        .padding()
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: appTheme.listItemMapHeight)

            HStack {
                Button {
                    router.openCaseMoveOnMap()
                } label: {
                    Image(systemName: "map.fill")
                        .frame(width: 24, height: 24)
                    Text(t.t("caseForm.select_on_map"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(disabled)

                Button {
                    viewModel.useMyLocation()
                } label: {
                    Image("ic_use_my_location", bundle: .module)
                        .frame(width: 24, height: 24)
                    Text(t.t("caseForm.use_my_location"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(disabled)
            }
            .padding()

            CaseAddressFormFields(locationData: locationData)

            TextField(t.t("formLabels.cross_street"), text: $locationData.crossStreetNearbyLandmark)
                .focused($focusState, equals: .anyTextInput)
                .textFieldBorder()
                .disabled(disabled)
                .padding([.horizontal, .bottom])

            VStack(alignment: .leading) {
                ForEach(viewModel.flagTranslateKeys, id: \.self) { key in
                    let isSelected: Bool = {
                        switch (key) {
                        case highPriorityLabelKey:
                            return viewModel.isHighPriority
                        case wrongLocationLabelKey:
                            return locationData.hasWrongLocation
                        case orgMemberLabelKey:
                            return viewModel.isAssignedToOrgMember
                        default:
                            return false
                        }
                    }()
                    Button {
                        let toggleSelected = !isSelected
                        switch (key) {
                        case highPriorityLabelKey:
                            viewModel.isHighPriority = toggleSelected
                        case wrongLocationLabelKey:
                            locationData.hasWrongLocation = toggleSelected
                        case orgMemberLabelKey:
                            viewModel.isAssignedToOrgMember = toggleSelected
                        default:
                            print("Flag \(key) does not update any state")
                        }
                    } label: {
                        let label = t.t(key)
                        CheckboxTextView(isChecked: isSelected, text: label)
                    }
                    .listItemModifier()
                }
            }
            .disabled(disabled)
            .padding(.leading)

            VStack(alignment: .leading)
            {
                Text(t.t("formLabels.notes"))

                Button {
                    router.openCaseAddNote()
                } label : {
                    HStack {
                        Image("ic_note", bundle: .module)
                            .frame(width: 24, height: 24)
                        Text(t.t("caseView.add_note"))
                    }
                }
                .disabled(disabled)
            }
            .padding(.leading)

        }
        .onChange(of: focusState) { focusableViewState.focusState = $0 }
    }
}

private struct CaseAddressFormFields: View {
    @Environment(\.translator) var t: KeyAssetTranslator

    @EnvironmentObject var viewModel: CreateEditCaseViewModel
    @EnvironmentObject var editableView: EditableView
    @EnvironmentObject private var focusableViewState: TextInputFocusableView

    @ObservedObject var locationData: LocationInputData

    @FocusState private var focusState: TextInputFocused?

    var body: some View {
        let disabled = editableView.disabled

        if locationData.isEditingAddress ||
            locationData.hasWrongLocation ||
            locationData.streetAddressError.isNotBlank ||
            locationData.zipCodeError.isNotBlank ||
            locationData.cityError.isNotBlank ||
            locationData.countyError.isNotBlank ||
            locationData.stateError.isNotBlank {

            Group {
                Group {
                    ErrorTextView(text: locationData.streetAddressError)
                    TextField(t.t("formLabels.address"), text: $locationData.streetAddress)
                        .focused($focusState, equals: .caseInfoStreetAddress)
                        .textFieldBorder()
                        .padding(.bottom)

                    ErrorTextView(text: locationData.cityError)
                    TextField(t.t("formLabels.city"), text: $locationData.city)
                        .focused($focusState, equals: .caseInfoCity)
                        .textFieldBorder()
                        .padding(.bottom)
                }

                Group {
                    ErrorTextView(text: locationData.countyError)
                    TextField(t.t("formLabels.county"), text: $locationData.county)
                        .focused($focusState, equals: .caseInfoCounty)
                        .textFieldBorder()
                        .padding(.bottom)

                    ErrorTextView(text: locationData.stateError)
                    TextField(t.t("formLabels.state"), text: $locationData.state)
                        .focused($focusState, equals: .caseInfoState)
                        .textFieldBorder()
                        .padding(.bottom)

                    ErrorTextView(text: locationData.zipCodeError)
                    TextField(t.t("formLabels.postal_code"), text: $locationData.zipCode)
                        .focused($focusState, equals: .caseInfoZipCode)
                        .textFieldBorder()
                        .padding(.bottom)
                }
            }
            .disabled(disabled)
            .padding(.horizontal)

        } else {
            let addressSummary = locationData.addressSummary
            if addressSummary.isNotEmpty {
                ZStack(alignment: .bottomTrailing) {
                    let addressText = addressSummary.joined(separator: "\n")
                    Text(addressText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    HStack(spacing: appTheme.gridItemSpacing) {
                        Button {
                            locationData.clearAddress()
                        } label: {
                            Image(systemName: "trash.fill")
                                .frame(width: 24, height: 24)
                        }
                        Button {
                            locationData.isEditingAddress = true
                        } label: {
                            Image(systemName: "pencil")
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding()
                }
                .roundedBorder()
                .disabled(disabled)
                .padding()
            }
        }
    }
}

private struct DisplayFormFieldLabel: View {
    @Environment(\.translator) var t: KeyAssetTranslator
    let node: FormFieldNode

    var body: some View {
        Text(t.t(node.formField.label))
        if node.formField.help.isNotBlank {
            HelpIcon(node.formField.help)
        }
    }
}

struct DisplayFormField: View {
    @Environment(\.translator) var t: KeyAssetTranslator

    @EnvironmentObject var editableView: EditableView
    @EnvironmentObject var focusableViewState: TextInputFocusableView

    @Binding var checkedData: ObservableBoolDictionary
    @Binding var contentData: ObservableStringDictionary

    @State private var multiSelected: Set<String> = []

    let node: FormFieldNode

    @FocusState private var focusState: TextInputFocused?

    var body: some View {
        let disabled = editableView.disabled

        VStack {
            switch node.formField.htmlType {
            case "text":
                HStack {
                    DisplayFormFieldLabel(node: node)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TextField(t.t(node.formField.placeholder), text: $contentData[node.fieldKey])
                    .focused($focusState, equals: .anyTextInput)
                    .textFieldBorder()
                    .disabled(disabled)
                    .padding(.bottom)

            case "textarea":
                HStack {
                    DisplayFormFieldLabel(node: node)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                LargeTextEditor(text: $contentData[node.fieldKey])
                    .disabled(disabled)
                    .padding(.bottom)

            case "checkbox":
                HStack {
                    CheckboxView(
                        checked: $checkedData[node.fieldKey],
                        text: node.formField.label
                    )
                    .disabled(disabled)
                    if node.formField.help.isNotBlank {
                        HelpIcon(node.formField.help)
                    }
                    Spacer()
                }
                .frame(minHeight: appTheme.rowItemHeight)

            case "select":
                HStack {
                    DisplayFormFieldLabel(node: node)
                    Spacer()
                    let options = node.options
                    let sortedOptions = options
                        .map { $0 }
                        .sorted { a, b in
                            a.value.localizedCompare(b.value) == .orderedAscending
                        }
                    Picker("", selection: $contentData[node.fieldKey]) {
                        ForEach(sortedOptions, id: \.key) { (key, value) in
                            let text = t.t(options[key]!)
                            Text(text)
                        }
                    }
                    .disabled(disabled)
                }
                .frame(minHeight: appTheme.rowItemHeight)

            case "multiselect":
                HStack {
                    DisplayFormFieldLabel(node: node)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                FlowStack(
                    alignment: .leading,
                    horizontalSpacing: 8,
                    verticalSpacing: 8
                ) {
                    let selectionString = contentData[node.fieldKey]
                    var selected = { () -> Set<String> in
                        var set = multiSelected
                        if set.isEmpty {
                            let selectOptions = Array(selectionString.split(separator: ","))
                                .map { String($0) }
                                .filter { $0.isNotBlank }
                            set = Set(selectOptions)
                        }
                        return set
                    }()
                    ForEach(Array(node.options.keys), id: \.self) { option in
                        let isSelected = selected.contains(option)
                        Button {
                            if isSelected {
                                selected.remove(option)
                            } else {
                                selected.insert(option)
                            }
                            contentData[node.fieldKey] = selected.joined(separator: ",")
                            multiSelected = selected
                        } label : {
                            Text(t.t(option))
                            // TODO: Common styles
                                .padding()
                                .background( isSelected ? Color.yellow : Color.white)
                                .cornerRadius(40)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(
                                            Color.black,
                                            lineWidth: isSelected ? 0 : 1
                                        )
                                )
                        }
                        .tint(.black)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(disabled)
                .padding([.bottom])
            case "cronselect":
                Text("Frequency types under development")
            case "h4":
                Text("h4")
                Text(t.t(node.formField.label))
            case "h5":
                let isChecked = checkedData[node.fieldKey]
                HStack {
                    if node.formField.isReadOnly {
                        Button {
                            checkedData[node.fieldKey] = !isChecked
                        } label : {
                            HStack {
                                DisplayFormFieldLabel(node: node)
                                Spacer()
                                Image(systemName: collapseIconName(!isChecked))
                            }
                        }
                    } else {
                        CheckboxView(
                            checked: $checkedData[node.fieldKey],
                            text: t.t(node.formField.label)
                        )
                        .disabled(disabled)
                    }
                    Spacer()
                }
                if isChecked {
                    ForEach(node.children, id: \.id) { childNode in
                        HStack {
                            DisplayFormField(
                                checkedData: $checkedData,
                                contentData: $contentData,
                                node: childNode
                            )
                            .padding(.leading)
                        }
                        .frame(minHeight: appTheme.rowItemHeight, alignment: .leading)
                    }
                }
            default:
                HStack {
                    Text(t.t(node.formField.label))
                }
            }
        }
        .onChange(of: focusState) { focusableViewState.focusState = $0 }
    }
}

private struct FrequencySelectView: View {
    @Environment(\.translator) var t: KeyAssetTranslator

    @Binding var checkedData: ObservableBoolDictionary

    let node: FormFieldNode

    @State var tempDailyWeekly = ""
    @State var tempSelected: [String] = []
    @State var tempValue = 1
    @State var tempDate = Date()
    @State var tempSelectedRadio = ""

    var body: some View {
        VStack(alignment: .leading) {
            let isChecked = checkedData[node.fieldKey]
            HStack {
                CheckboxView(
                    checked: $checkedData[node.fieldKey],
                    text: t.t(node.formField.label)
                )
                .disabled(isChecked)

                Spacer ()
            }
            if(isChecked) {
                HStack {
                    Button {
                        tempDailyWeekly = "daily"
                    } label : {
                        let isSelected = tempDailyWeekly == "daily"
                        HStack {
                            Spacer()
                            Text("t.tDaily")
                            // TODO: Common styles
                            Spacer()
                        }
                        .padding()
                        .background( isSelected ? Color.yellow : Color.white)
                        .cornerRadius(40)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    Color.black,
                                    lineWidth: isSelected ? 0 : 1
                                )
                        )
                    }
                    .tint(.black)

                    Button {
                        tempDailyWeekly = "weekly"
                    } label : {
                        let isSelected = tempDailyWeekly == "weekly"
                        HStack {
                            Spacer()
                            Text("t.weekly")
                            // TODO: Common styles
                            Spacer()
                        }
                        .padding()
                        .background( isSelected ? Color.yellow : Color.white)
                        .cornerRadius(40)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    Color.black,
                                    lineWidth: isSelected ? 0 : 1
                                )
                        )
                    }
                    .tint(.black)

                }
                // TODO: Test
                if tempDailyWeekly == "weekly" {

                    Stepper(value: $tempValue,
                            in: 1...99,
                            step: 1) {
                        HStack {
                            Text("t.tRecur Every")
                            Text(tempValue.description)
                                .frame(width: 30, height: 30)
                                .padding()
                                .background(appTheme.colors.attentionBackgroundColor)
                                .cornerRadius(appTheme.cornerRadius)
                            Text("week(s) on:")
                        }
                    }
                    let options = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
                    FlowStack(
                        alignment: .leading,
                        horizontalSpacing: 8,
                        verticalSpacing: 8
                    ) {
                        ForEach(options, id: \.self) { option in
                            let isSelected = tempSelected.contains(option)
                            Button {
                                if isSelected {
                                    tempSelected.remove(at: tempSelected.firstIndex(of: option)!)
                                } else {
                                    tempSelected.append(option)
                                }
                            } label : {
                                Text(option)
                                // TODO: Common styles
                                    .padding()
                                    .frame(width: 75)
                                    .background( isSelected ? Color.yellow : Color.white)
                                    .cornerRadius(40)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(
                                                Color.black,
                                                lineWidth: isSelected ? 0 : 1
                                            )
                                    )
                            }
                            .tint(.black)
                        }
                    }

                    SelectEndDate(date: $tempDate)
                        .padding(.top)

                } else if tempDailyWeekly == "daily" {
                    RadioButtons(selected: $tempSelectedRadio, options: ["t.treccurringSchedule", "t.teveryWeekday"])

                    SelectEndDate(date: $tempDate)
                        .padding(.top)
                }
            }
        }
    }
}

// TODO: Reuse calendar range from Filters
private struct SelectEndDate: View {

    @Binding var date: Date
    @State var showCalendar = false
    @State var dateSelected = false

//    @State var start: Date?
//    @State var end: Date?

    var body: some View {
        HStack {
            Image(systemName: "calendar")
            Text("t.tSelect end date")
            if(dateSelected)
            {
                Text(date.formatted(.dateTime.day().month().year()))
                Image(systemName: "xmark")
                    .onTapGesture {
                        dateSelected = false
                    }
            }

        }
        .onTapGesture {
            showCalendar = true
            dateSelected = true
        }
        .sheet(isPresented: $showCalendar) {
//            CalendarSelectView(start: $start, end: $end, showCalendar: $showCalendar)
            SingleDateCalendar(date: $date, showCalendar: $showCalendar)
        }
    }
}

private struct SingleDateCalendar: View {
    @Environment(\.translator) var t: KeyAssetTranslator
    @Binding var date: Date
    @Binding var showCalendar: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                let text2 = date.formatted(.dateTime.day().month().year())
                Text("t.tEnd date: " + text2)
                    .fontHeader3()
                Spacer()
                Button {
                    showCalendar = false
                } label: {
                    Text(t.t("actions.save"))
                }
            }
            .padding()
            DatePicker(
                "Start Date",
                selection: $date,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CreateEditCaseSaveActions: View {
    @Environment(\.translator) var t: KeyAssetTranslator
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var editableView: EditableView

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label : {
                Text(t.t("actions.cancel"))
            }
            .styleCancel()

            Button {
                // TODO: Do
            } label : {
                Text(t.t("actions.save_claim"))
            }
            .stylePrimary()
            .frame(maxWidth: .infinity)

            Button {
                // TODO: Do
            } label : {
                Text(t.t("actions.save"))
            }
            .stylePrimary()
        }
    }
}

struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}
