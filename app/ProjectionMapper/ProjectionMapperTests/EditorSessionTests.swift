import Foundation
import Testing

@MainActor
struct EditorSessionTests {
    @Test func newProjectStartsClean() {
        let session = EditorSession()
        #expect(session.project.name == MappingProject.defaultName)
        #expect(!session.hasUserChanges)
        #expect(session.isSidebarVisible && session.isInspectorVisible)
    }

    @Test func renamePreservesIdentityAndCreationDate() {
        let created = Date(timeIntervalSince1970: 100)
        let changed = Date(timeIntervalSince1970: 200)
        let project = MappingProject(now: created)
        let session = EditorSession(project: project)
        session.renameProject("Halloween House", now: changed)
        #expect(session.project.id == project.id)
        #expect(session.project.createdAt == created)
        #expect(session.project.modifiedAt == changed)
        #expect(session.hasUserChanges)
    }

    @Test func editingTrimsWhitespaceAndRestoresEmptyName() {
        let session = EditorSession()
        session.renameProject("  House  ")
        session.finishNameEditing()
        #expect(session.project.name == "House")
        session.renameProject(" \n ")
        session.finishNameEditing()
        #expect(session.project.name == MappingProject.defaultName)
        #expect(!session.hasUserChanges)
    }

    @Test func resetReplacesProjectAndPreservesPanelPreferences() {
        let session = EditorSession()
        let previousID = session.project.id
        session.renameProject("House")
        session.isSidebarVisible = false
        let resetDate = Date(timeIntervalSince1970: 300)
        session.resetProject(now: resetDate)
        #expect(session.project.id != previousID)
        #expect(session.project.createdAt == resetDate)
        #expect(session.project.modifiedAt == resetDate)
        #expect(!session.hasUserChanges)
        #expect(!session.isSidebarVisible)
    }

    @Test func unchangedNameDoesNotChangeModificationDate() {
        let date = Date(timeIntervalSince1970: 100)
        let session = EditorSession(project: MappingProject(now: date))
        session.renameProject(MappingProject.defaultName, now: Date(timeIntervalSince1970: 200))
        #expect(session.project.modifiedAt == date)
        session.isInspectorVisible = false
        #expect(!session.hasUserChanges)
    }
}
