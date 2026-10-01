import SwiftUI
import FamilyControls

/// App/category picker. Edits a local copy of the selection and reports it on
/// Done, or nil on Cancel, so cancelling never changes anything.
@available(iOS 15.0, *)
struct ContentView: View {
    @State private var selection: FamilyActivitySelection
    private let onFinish: (FamilyActivitySelection?) -> Void

    init(
        initialSelection: FamilyActivitySelection,
        onFinish: @escaping (FamilyActivitySelection?) -> Void
    ) {
        _selection = State(initialValue: initialSelection)
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationBarTitle("Select Apps", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        onFinish(nil)
                    },
                    trailing: Button("Done") {
                        onFinish(selection)
                    }
                )
        }
        .navigationViewStyle(.stack)
    }
}

@available(iOS 15.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(initialSelection: FamilyActivitySelection()) { _ in }
    }
}
