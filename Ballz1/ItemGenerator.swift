//
//  ItemGenerator.swift
//  Ballz1
//
//  Created by Gabriel Busto on 9/18/18.
//  Copyright © 2018 Self. All rights reserved.
//

import SpriteKit
import GameplayKit

class ItemGenerator {
    
    // -------------------------------------------------------------
    // MARK: Public properties
    
    // Rows of items for which this generator is responsible
    public var itemArray: [[Item]] = []
    
    // Maximum hit count for a HitBlock
    public var maxHitCount = Int(10)
    
    // -------------------------------------------------------------
    // MARK: Private attributes
    private var igState: ItemGeneratorState?
    static let ItemGeneratorPath = "ItemGenerator"
    
    // Number of items to fit on each row
    private var numItemsPerRow = Int(0)
    // The minimum number of items per row
    private var minItemsPerRow = Int(2)
    
    // Number of items that this generator has generated
    private var numItemsGenerated = Int(0)
    
    private var blockSize: CGSize?
    private var ballRadius: CGFloat?
    
    // Item types that this generator can generate; for example, after 100 turns, maybe you want to start adding special kinds of blocks
    // The format is [ITEM_TYPE: PERCENTAGE_TO_GENERATE]
    private var itemTypeDict: [Int: Int] = [:]
    // This is an array containing the item types
    // There is exist as many items types in the array as the percentage; for example, if hit blocks have a 65% chance of being selected, there will be 65 hit blocks in this array
    private var itemTypeArray: [Int] = []
    // Total percentage that will grow as items are added to the itemTypeDict; it is updated in the addItemType function
    private var totalPercentage = Int(0)
    // Used to mark item types to know what item types are allowed to be generated
    private var EMPTY = Int(0)
    private var HIT_BLOCK = Int(1)
    private var BALL = Int(2)
    private var CURRENCY = Int(3)
    
    // An Int to let holder of this object know when the ItemGenerator is ready
    private var actionsStarted = Int(0)
    
    
    // MARK: State handling functions
    struct ItemGeneratorState: Codable {
        var maxHitCount: Int
        var totalPercentage: Int
        var itemTypeDict: [Int: Int]
        // An array of tuples where index 0 is the item type (EMPTY, HIT_BLOCK, BALL, etc) and index 1 is the hit block count (it's only really needed for hit block items)
        var itemArray: [[Int]]
        var itemHitCountArray: [[Int]]
        var itemTypeArray: [Int]
        
        enum CodingKeys: String, CodingKey {
            case maxHitCount
            case totalPercentage
            case itemTypeDict
            case itemArray
            case itemHitCountArray
            case itemTypeArray
        }
    }
    
    public func saveState(restorationURL: URL) {
        let url = restorationURL.appendingPathComponent(ItemGenerator.ItemGeneratorPath)
        do {
            igState!.maxHitCount = maxHitCount
            igState!.totalPercentage = totalPercentage
            igState!.itemTypeDict = itemTypeDict
            
            var savedItemArray: [[Int]] = []
            var savedHitCountArray: [[Int]] = []
            for row in itemArray {
                var newItemRow: [Int] = []
                var itemHitCountRow: [Int] = []
                for item in row {
                    if item is SpacerItem {
                        newItemRow.append(EMPTY)
                        itemHitCountRow.append(0)
                    }
                    else if item is HitBlockItem {
                        let block = item as! HitBlockItem
                        newItemRow.append(HIT_BLOCK)
                        itemHitCountRow.append(block.hitCount!)
                    }
                    else if item is BallItem {
                        newItemRow.append(BALL)
                        itemHitCountRow.append(0)
                    }
                    else if item is CurrencyItem {
                        newItemRow.append(CURRENCY)
                        itemHitCountRow.append(0)
                    }
                }
                savedItemArray.append(newItemRow)
                savedHitCountArray.append(itemHitCountRow)
            }
            
            igState!.itemArray = savedItemArray
            igState!.itemHitCountArray = savedHitCountArray
            igState!.itemTypeArray = itemTypeArray
            
            let data = try PropertyListEncoder().encode(igState!)
            try data.write(to: url)
            print("Saved item generator state")
        }
        catch {
            print("Failed to save item generator state: \(error)")
        }
    }
    
    public func loadState(restorationURL: URL) -> Bool {
        do {
            let data = try Data(contentsOf: restorationURL)
            igState = try PropertyListDecoder().decode(ItemGeneratorState.self, from: data)
            print("Loaded item generator state")
            return true
        }
        catch {
            print("Failed to load item generator state: \(error)")
            return false
        }
    }
    
    // MARK: Public functions
    required init(blockSize: CGSize, ballRadius: CGFloat, maxHitCount: Int, numItems: Int, restorationURL: URL) {
        self.blockSize = blockSize
        self.ballRadius = ballRadius
        numItemsPerRow = numItems
        
        let url = restorationURL.appendingPathComponent(ItemGenerator.ItemGeneratorPath)
        // Try to load state and if not initialize things to their default values
        if false == loadState(restorationURL: url) {
            // Initialize the allowed item types with only one type for now
            totalPercentage = 0
            addItemType(type: HIT_BLOCK, percentage: 65)
            addItemType(type: BALL, percentage: 25)
            addItemType(type: CURRENCY, percentage: 10)
            
            igState = ItemGeneratorState(maxHitCount: maxHitCount, totalPercentage: totalPercentage, itemTypeDict: itemTypeDict, itemArray: [], itemHitCountArray: [], itemTypeArray: itemTypeArray)
        }
        
        // Set these global variables based on the item generator state
        self.maxHitCount = igState!.maxHitCount
        self.totalPercentage = igState!.totalPercentage
        self.itemTypeDict = igState!.itemTypeDict
        self.itemTypeArray = igState!.itemTypeArray
        
        // Load items into the item array based on our saved item array and item hit count array
        if igState!.itemArray.count > 0 {
            for i in 0...(igState!.itemArray.count - 1) {
                var newRow: [Item] = []
                let row = igState!.itemArray[i]
                for j in 0...(row.count - 1) {
                    let itemType = row[j]
                    let item = generateItem(itemType: itemType)
                    newRow.append(item!)
                    if item! is SpacerItem {
                        continue
                    }
                    else if item! is HitBlockItem {
                        let block = item! as! HitBlockItem
                        // Load the block's hit count
                        block.updateHitCount(count: igState!.itemHitCountArray[i][j])
                    }
                    else if item! is BallItem {
                        // Don't need to do anything
                    }
                    else if item! is CurrencyItem {
                        // Don't need to do anything
                    }
                    numItemsGenerated += 1
                }
                print("Added new row to the item array")
                itemArray.append(newRow)
            }
        }
    }
    
    public func addItemType(type: Int, percentage: Int) {
        itemTypeDict[type] = percentage
        totalPercentage += percentage

        itemTypeArray = []
        for itemType in itemTypeDict.keys {
            let percentage = itemTypeDict[itemType]
            print("Adding \(percentage!) items of type \(itemType)")
            for _ in 1...percentage! {
                itemTypeArray.append(itemType)
            }
        }
    }
    
    public func generateRow() -> [Item] {
        var newRow: [Item] = []

        var str = ""
        for _ in 1...numItemsPerRow {
            if Int.random(in: 1...100) < 60 {
                let type = itemTypeArray.randomElement()!
    
                let item = generateItem(itemType: type)
                newRow.append(item!)
                if item! is BallItem {
                    str += "[B]"
                }
                else if item! is HitBlockItem {
                    str += "[H]"
                }
                else if item! is CurrencyItem {
                    str += "[C]"
                }
                else {
                    print("Unknown item...?")
                }
                numItemsGenerated += 1
            }
            // If Int.random() didn't return a number < 60, add a spacer item anyways; each slot in a row needs to be occupied (i.e. each row must contain at least numItemsPerRow number of items)
            else {
                let spacer = SpacerItem()
                newRow.append(spacer)
                str += "[S]"
            }
        }
        print(str)
        
        itemArray.append(newRow)
        
        return newRow
    }
    
    public func animateItems(_ action: SKAction) {
        // This count will not include spacer items, so they should be skipped in the animation loop below
        actionsStarted = getItemCount()
        
        for row in itemArray {
            for item in row {
                if item is SpacerItem {
                    // SpacerItems aren't included in the actionsStarted count so skip their animation here
                    continue
                }
                
                // If the item is invisible, have it fade in
                if 0 == item.getNode().alpha {
                    // If this is the newest row
                    let fadeIn = SKAction.fadeIn(withDuration: 1)
                    item.getNode().run(SKAction.group([fadeIn, action])) {
                        self.actionsStarted -= 1
                    }
                }
                else {
                    item.getNode().run(action) {
                        self.actionsStarted -= 1
                    }
                }
            }
        }
    }
    
    public func isReady() -> Bool {
        // This is used to prevent the user from shooting while the block manager isn't ready yet
        return (0 == actionsStarted)
    }
    
    public func hit(name: String) {
        for row in itemArray {
            for item in row {
                if item.getNode().name == name {
                    item.hitItem()
                    if item.getNode().name!.starts(with: "ball") {
                        // If this item was a ball, increase the max hit count by 2 because it will be transferred over to the ball manager
                        maxHitCount += 2
                    }
                }
            }
        }
    }
    
    // Looks for items that should be removed; each Item keeps track of its state and whether or not it's time for it to be removed.
    // If item.removeItem() returns true, it's time to remove the item; it will be added to an array of items that have been removed and returned to the model
    public func removeItems() -> [Item] {
        var removedItems : [Item] = []
        
        // Return out so we don't cause an error with the loop logic below
        if itemArray.isEmpty {
            return removedItems
        }
        
        for i in 0...(itemArray.count - 1) {
            let row = itemArray[i]
            var newRow: [Item] = []
            
            // Remove items that should be removed and add them to an array that we will return
            // If an item is removed, replace it with a spacer item
            let _ = row.filter {
                // Perform a remove action if needed
                if $0.removeItem() {
                    // Remove this item from the array if that evaluates to true (meaning it's time to remove the item)
                    removedItems.append($0)
                    // Replace it with a spacer item
                    let item = SpacerItem()
                    newRow.append(item)
                    return false
                }
                // Keep this item in the array
                newRow.append($0)
                return true
            }
            
            // Assign the newly created row to this index
            itemArray[i] = newRow
        }
        
        // After removing all necessary items, check to see if there any empty rows that can be removed
        //removeEmptyRows()
        removeEmptyRows()
        
        // Return all items that were removed
        return removedItems
    }
    
    // Iterate over all items to see if any are within (rowHeight * numRows) of the floor
    // Returns true if it can items, false otherwise
    public func canAddItems(_ floor: CGFloat, _ rowHeight: CGFloat, _ numRows: Int) -> Bool {
        for row in itemArray {
            for item in row {
                // We don't care about spacer items
                if item is SpacerItem {
                    continue
                }
                
                if (item.getNode().position.y - (rowHeight * CGFloat(numRows))) < floor {
                    return false
                }
            }
        }
        print("New number of rows \(itemArray.count)")
        
        return true
    }
    
    // MARK: Private functions
    // Actually generate the item to be placed in the array
    private func generateItem(itemType: Int) -> Item? {
        switch itemType {
        case EMPTY:
            let item = SpacerItem()
            return item
        case HIT_BLOCK:
            let item = HitBlockItem()
            item.initItem(num: numItemsGenerated, size: blockSize!)
            let block = item as HitBlockItem
            let min = Int(maxHitCount / 2)
            block.setHitCount(count: Int.random(in: min...maxHitCount))
            return item
        case BALL:
            let size = CGSize(width: ballRadius!, height: ballRadius!)
            let item = BallItem()
            item.initItem(num: numItemsGenerated, size: size)
            return item
        case CURRENCY:
            let item = CurrencyItem()
            item.initItem(num: numItemsGenerated, size: blockSize!)
            return item
        default:
            return nil
        }
    }
    
    // Gets the item count (doesn't include spacer items)
    private func getItemCount() -> Int {
        var count = Int(0)
        for row in itemArray {
            for item in row {
                if item is SpacerItem {
                    continue
                }
                
                count += 1
            }
        }
        
        return count
    }
    
    /*
     This is how we need to remove empty rows. If we have rows of items like these:
     [H] [S] [S] [B]
     [S] [S] [H] [S]
     [H] [S] [S] [H]
     (where H == hit block, B == ball, and S == spacer item)
     
     And we break the hit block in the 2nd row, we want that row to remain all spacer items in
     the event that we quit the game and come back. If we just remove that row as soon as it's
     empty and quit the game and have the item generator reload, the rows will look like this:
     [H] [S] [S] [B]
     [H] [S] [S] [H]
     
     which is incorrect. The layout of the items should be exactly the same.
     */
    private func removeEmptyRows() {
        while true {
            // If there are no rows left, return out
            if 0 == itemArray.count {
                return
            }
            
            let row = itemArray[0]
            for item in row {
                if item is SpacerItem {
                    continue
                }
                // As soon as we get to a row that doesn't just contain spacer items, return
                return
            }
            // If it is empty, remove it from the array and loop around to check the row before that
            let _ = itemArray.remove(at: 0)
        }
    }
}
