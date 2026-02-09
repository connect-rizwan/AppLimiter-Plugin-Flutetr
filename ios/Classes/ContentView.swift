import SwiftUI


import FamilyControls

@available(iOS 15.0, *)
struct ContentView: View {
    @State private var isDiscouragedPresented = true
    @State private var isEncouragedPresented = false

    @EnvironmentObject var model: MyModel
    @Environment(\.presentationMode) var presentationMode

    @ViewBuilder
    func contentView() -> some View {
        switch globalMethodCall {
        case "selectAppsToDiscourage":
            FamilyActivityPicker(selection: $model.selectionToDiscourage)
                .onChange(of: model.selectionToDiscourage) { _ in
                    model.setShieldRestrictions()
                }
        case "selectAppsToEncourage":
            FamilyActivityPicker(selection: $model.selectionToEncourage)
                .onChange(of: model.selectionToEncourage) { _ in
                    MySchedule.setSchedule()
                }
        case "selectAppsForBlocking":
            FamilyActivityPicker(selection: $model.selectedApps)
        default:
            Text("Default")
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                contentView()
            }
            .navigationBarTitle("Select Apps", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    switch globalMethodCall {
                    case "selectAppsToDiscourage":
                        model.setShieldRestrictions()
                    case "selectAppsToEncourage":
                        MySchedule.setSchedule()
                    case "selectAppsForBlocking":
                        let total = model.selectedApps.applicationTokens.count + model.selectedApps.categoryTokens.count
                        print("AppPicker: Selected \(total) items")
                    default:
                        break
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

@available(iOS 15.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MyModel())
    }
}
