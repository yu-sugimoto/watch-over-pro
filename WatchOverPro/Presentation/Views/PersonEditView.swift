import SwiftUI

struct PersonEditView: View {
    let member: FamilyMember
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var relationship: Relationship
    @State private var age: Int
    @State private var notes: String
    @State private var isSaving = false

    init(member: FamilyMember) {
        self.member = member
        _name = State(initialValue: member.displayName)
        _relationship = State(initialValue: member.relationship)
        _age = State(initialValue: member.age)
        _notes = State(initialValue: member.notes)
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
                        // TODO: Save changes via FamilyRepository
                        dismiss()
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
}
