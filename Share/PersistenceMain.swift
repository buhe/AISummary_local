//
//  Persistence.swift
//  Share
//
//  Created by 顾艳华 on 2023/7/3.
//

import CoreData
import PersistentHistoryTrackingKit

class NSCustomPersistentContainer: NSPersistentContainer {
    
    override open class func defaultDirectoryURL() -> URL {
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.buhe.abc")
        return storeURL!
    }

}
struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSCustomPersistentContainer(name: "Share")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        // Prepare your Container
        let desc = container.persistentStoreDescriptions.first!
        // Turn on persistent history tracking in persistentStoreDescriptions
        desc.setOption(true as NSNumber,
                       forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber,
                       forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.transactionAuthor = "main"
        // after loadPersistentStores
        let kit = PersistentHistoryTrackingKit(
            container: container,
            currentAuthor: "main",
            allAuthors: ["main", "ext"],
            userDefaults: UserDefaults.shared,
            logLevel: 3
        )
        kit.start()
    }
}
