import SwiftUI

struct PersonEditView: View {
    let person: WatchPerson
    let watchOverViewModel: WatchOverViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var relationship: Relationship
    @State private var age: Int
    @State private var notes: String
    @State private var isSaving = false

    init(person: WatchPerson, watchOverViewModel: WatchOverViewModel) {
        self.person = person
        self.watchOverViewModel = watchOverViewModel
        _name = State(initialValue: person.name)
        _relationship = State(initialValue: person.relationship)
        _age = State(initialValue: person.age)
        _notes = State(initialValue: person.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)
                    Picker("続柄", selection: $relationship) {
                        ForEach(Relationship.allCases, id: \.self) { rel in
                            Label(rel.label, systemImage: rel.icon).tag(rel)
                        }
                    }
                    Stepper("年齢: \(age)歳", value: $age, in: 1...120)
                }
                Section("メモ") {
                    TextField("持病や注意事項など", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存").fontWeight(.semibold)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        var updated = person
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.relationship = relationship
        updated.age = age
        updated.notes = notes
        await watchOverViewModel.updatePerson(updated)
        isSaving = false
        dismiss()
    }
}
