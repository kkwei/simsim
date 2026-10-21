//
//  Tools.swift
//  SimSim
//
//  Created by Daniil Smelov on 16/04/2018.
//  Copyright © 2018 Daniil Smelov. All rights reserved.
//

import Foundation
import Cocoa

//============================================================================
class Tools: NSObject
{
    //----------------------------------------------------------------------------
    struct Keys
    {
        static let fileName = "fileName"
        static let fileDate = "modificationDate"
        static let fileType = "fileType"
    }

    // 只在 main thread 存取；背景 preload 先建 local dict 再 dispatch 回 main merge
    private static var identifierCache: [String: String] = [:]

    //----------------------------------------------------------------------------
    class func readContainerIdentifier(atPath containerPath: String) -> String?
    {
        let plistPath = containerPath + ".com.apple.mobile_container_manager.metadata.plist"
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let metadata = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let identifier = metadata["MCMMetadataIdentifier"] as? String else
        {
            return nil
        }

        return identifier
    }

    //----------------------------------------------------------------------------
    class func containerIdentifier(uuid: String, atPath containerPath: String) -> String?
    {
        dispatchPrecondition(condition: .onQueue(.main))

        if let cached = identifierCache[uuid]
        {
            return cached
        }

        guard let identifier = readContainerIdentifier(atPath: containerPath) else
        {
            return nil
        }

        if identifierCache.count > 20_000
        {
            identifierCache.removeAll()
        }

        identifierCache[uuid] = identifier
        return identifier
    }

    //----------------------------------------------------------------------------
    class func preloadIdentifierCache()
    {
        let simulators = activeSimulators()
            .sorted { $0.date > $1.date }
            .prefix(Constants.maxRecentSimulators)

        let folders = ["data/Containers/Data/Application/",
                       "data/Containers/Shared/AppGroup/",
                       "data/Containers/Data/PluginKitPlugin/",
                       "data/Containers/Bundle/Application/"]

        var local: [String: String] = [:]

        for simulator in simulators
        {
            for folder in folders
            {
                let basePath = simulator.path + folder
                for uuid in allFilesAt(path: basePath) where uuid != Constants.Other.dsStore
                {
                    if let identifier = readContainerIdentifier(atPath: basePath + uuid + "/")
                    {
                        local[uuid] = identifier
                    }
                }
            }
        }

        DispatchQueue.main.async
        {
            identifierCache.merge(local) { current, _ in current }
        }
    }

    //----------------------------------------------------------------------------
    class func homeDirectoryPath() -> String
    {
        return NSHomeDirectory()
    }

    //----------------------------------------------------------------------------
    class func simulatorRootPath(byUUID uuid: String) -> String
    {
        return Tools.homeDirectoryPath() + "/" + Constants.Simulator.rootPath + "/" + uuid + "/"
    }

    
    //----------------------------------------------------------------------------
    class func getSimulatorProperties() -> NSDictionary?
    {
        let path = Tools.homeDirectoryPath() + "/Library/Preferences/com.apple.iphonesimulator.plist"
        return NSDictionary(contentsOfFile: path)
    }
    
    //----------------------------------------------------------------------------
    class func simulatorPaths() -> Set<String>
    {
        let properties = getSimulatorProperties()
        var simulatorPaths = Set<String>()
        
        if let currentSimulatorUuid = properties?["CurrentDeviceUDID"] as? String
        {
            _ = simulatorPaths.insert(simulatorRootPath(byUUID: currentSimulatorUuid))
        }
        
        if let devicePreferences = properties?["DevicePreferences"] as? NSDictionary
        {
            // we're running on xcode 9
            for uuid: NSString in devicePreferences.allKeys as! [NSString]
            {
                _ = simulatorPaths.insert(self.simulatorRootPath(byUUID: uuid as String))
            }
        }
        return simulatorPaths
    }

    //----------------------------------------------------------------------------
    class func activeSimulators() -> [Simulator]
    {
        let paths = self.simulatorPaths()
        var simulators = [Simulator]()
    
        for path in paths
        {
            let propertiesPath = path + Constants.Simulator.deviceProperties
            guard let properties = NSDictionary(contentsOfFile: propertiesPath) as? [AnyHashable : Any] else
            {
                continue
            }
            
            let simulator = Simulator(dictionary: properties, path: path)
            
            simulators.append(simulator)
        }
        return simulators
    }

    //----------------------------------------------------------------------------
    class func installedApps(on simulator: Simulator) -> [Application]
    {
        let installedApplicationsDataPath = simulator.path + ("data/Containers/Data/Application/")
        let installedApplications = Tools.getSortedFiles(fromFolder: installedApplicationsDataPath)
        
        return installedApplications.compactMap
        {
            Application(dictionary: $0, simulator: simulator)
        }
    }

    //----------------------------------------------------------------------------
    class func sharedAppGroups(on simulator: Simulator) -> [AppGroup]
    {
        let appGroupsDataPath = simulator.path + ("data/Containers/Shared/AppGroup/")
        let appGroups = Tools.getSortedFiles(fromFolder: appGroupsDataPath)

        return appGroups
            .compactMap
            {
                AppGroup(dictionary: $0 as! [AnyHashable: Any], simulator: simulator)
            }
            .filter
            {
                !$0.isAppleAppGroup
            }
    }
    
    //----------------------------------------------------------------------------
    class func appExtensions(on simulator: Simulator) -> [AppExtension]
    {
        let appExtensionsDataPath = simulator.path + ("data/Containers/Data/PluginKitPlugin/")
        let appExtensions = Tools.getSortedFiles(fromFolder: appExtensionsDataPath)
        
        return appExtensions
            .compactMap
            {
                AppExtension(dictionary: $0 as! [AnyHashable: Any], simulator: simulator)
            }
            .filter
            {
                !$0.isAppleExtension
            }
    }

    //----------------------------------------------------------------------------
    class func commanderOneAvailable() -> Bool
    {
        let fileManager = FileManager.default
        
        // Check for App Store version
        let isApplicationExist: Bool = fileManager.fileExists(atPath: Constants.Paths.commanderOneApp)
        let isApplicationProExist: Bool = fileManager.fileExists(atPath: Constants.Paths.commanderOneProApp)
        
        if isApplicationExist || isApplicationProExist
        {
            return true
        }
        
        // Check for version from Web
        let plistPath = NSHomeDirectory() + "/" + Constants.Other.commanderOnePlist
        let isPlistExist: Bool = fileManager.fileExists(atPath: plistPath)
        return isPlistExist
    }

    //----------------------------------------------------------------------------
    class func allFilesAt(path: String) -> [String]
    {
        let files = try? FileManager.default.contentsOfDirectory(atPath: path)
        return files ?? []
    }
    
    //----------------------------------------------------------------------------
    class func getFiles(fromFolder folderPath: String) -> [NSDictionary]
    {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileResourceTypeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folderPath),
                                                                 includingPropertiesForKeys: keys,
                                                                 options: [])) ?? []
        var filesAndProperties: [NSDictionary] = []

        for url in urls
        {
            let file = url.lastPathComponent
            if !(file == Constants.Other.dsStore)
            {
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      let modificationDate = values.contentModificationDate else
                {
                    continue
                }

                filesAndProperties.append([
                    Keys.fileName : file,
                    Keys.fileDate : modificationDate,
                    Keys.fileType : values.fileResourceType?.rawValue ?? ""
                ])
            }
        }

        return filesAndProperties
    }
    
    //----------------------------------------------------------------------------
    class func getName(from file: NSDictionary) -> NSString
    {
        return file.object(forKey: Keys.fileName) as! NSString
    }
    
    //----------------------------------------------------------------------------
    class func getSortedFiles(fromFolder folderPath: String) -> [NSDictionary]
    {
        let filesAndProperties = getFiles(fromFolder: folderPath)
        
        // 先取出 Date 再排，避免 comparator 內反覆做 NSDictionary -> Date 的 bridging cast
        let sortedFiles = filesAndProperties
            .map { ($0[Keys.fileDate] as? Date ?? Date.distantPast, $0) }
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }

        return sortedFiles
    }
    
    //----------------------------------------------------------------------------
    class func getApplicationFolder(fromPath folderPath: String) -> String
    {
        return allFilesAt(path: folderPath)
               .first(where: { URL(fileURLWithPath: $0).pathExtension == "app" })!
    }
}
