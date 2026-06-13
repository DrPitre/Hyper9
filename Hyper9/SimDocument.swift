import SwiftUI
import UniformTypeIdentifiers

// Define your document type.
struct SimDocument: FileDocument {
    // Document holds its own simulator instance; the loaded memory is the document data.
    var disassembler = Turbo9ViewModel()

    // Use the project's exported UTI (declared in Info.plist) plus generic data as a
    // fallback so any binary file can be opened as a memory image.
    static var readableContentTypes: [UTType] {
        var types: [UTType] = [.data]
        if let custom = UTType("org.pitre.Hyper9.document") {
            types.insert(custom, at: 0)
        }
        return types
    }

    static var writableContentTypes: [UTType] {
        if let custom = UTType("org.pitre.Hyper9.document") {
            return [custom]
        }
        return [.data]
    }

    init() {}

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        disassembler.loadDocumentSnapshot(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = disassembler.documentSnapshotData()
        return FileWrapper(regularFileWithContents: data)
    }
}
