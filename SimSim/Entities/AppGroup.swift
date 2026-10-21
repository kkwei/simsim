//
//  AppGroup.swift
//  SimSim
//

import Foundation

//============================================================================
class AppGroup
{
    private let uuid: String
    let path: String
    let identifier: String

    //----------------------------------------------------------------------------
    var isAppleAppGroup: Bool
    {
        return identifier.isEmpty ||
            identifier.starts(with: "com.apple") ||
            identifier.starts(with: "group.com.apple") ||
            identifier.starts(with: "group.is.workflow") ||
            identifier.starts(with: "243LU875E5.groups.com.apple")
    }

    //----------------------------------------------------------------------------
    private init(uuid: String, path: String, identifier: String)
    {
        self.uuid = uuid
        self.path = path
        self.identifier = identifier
    }

    //----------------------------------------------------------------------------
    convenience init?(dictionary: [AnyHashable : Any], simulator: Simulator)
    {
        guard let uuid = dictionary[Tools.Keys.fileName] as? String else
        {
            return nil
        }
        
        let path = simulator.pathForAppGroup(withUUID: uuid)

        guard let identifier = Tools.containerIdentifier(uuid: uuid, atPath: path) else
        {
            return nil
        }

        self.init(uuid: uuid, path: path, identifier: identifier)
    }
}
