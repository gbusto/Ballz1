//
//  BallManager.swift
//  Ballz1
//
//  Created by Gabriel Busto on 9/14/18.
//  Copyright © 2018 Self. All rights reserved.
//

import SpriteKit
import GameplayKit

class BallManager {
    
    // MARK: Public properties
    public var numberOfBalls = Int(0)
    public var ballArray: [BallItem] = []
    
    // MARK: Private properties
    private var ballRadius: CGFloat?
    // Balls that have just been added from the ItemGenerator
    private var newBallArray: [BallItem] = []
    
    // This isn't ideal because it shouldn't be aware of any view attributes
    private var groundHeight = CGFloat(0)
    
    private var firstBallReturned = false
    
    private var numBallsActive = 0
    
    private var originPoint: CGPoint?
    
    private var bmState: BallManagerState?
    static let BallManagerPath = "BallManager"
    
    private var prevTurnState = BallManagerState(numberOfBalls: 0, originPoint: CGPoint(x: 0, y: 0))
    
    // MARK: State values
    // READY state means that all balls are at rest, all animations are complete
    // Changes from this state by GameScene when the user touches the screen to fire balls
    private var READY = Int(0)
    // SHOOTING state is when it's firing balls
    // Changes from this state by itself after all balls have been shot to notify GameScene to stop calling shootBall()
    private var SHOOTING = Int(1)
    // WAITING state is when all the balls have been fired and we're waiting for balls to return to the ground
    // Changes from this state by itself after all balls are at rest again to notify GameScene
    private var WAITING = Int(2)
    // DONE state tells GameScene that the BallManager is done and all balls are at rest again
    // Changes from this state by GameScene and used to tell when a "turn" is over and to add another row to the game scene
    private var DONE = Int(3)
    
    private var state = Int(0)
    
    private var direction : CGPoint?
    
    private var ballsOnFire = false
    
    private var swipedDown = false
    
    private var stoppedBalls: [BallItem] = []
    
    
    // MARK: State handling code
    struct BallManagerState: Codable {
        var numberOfBalls: Int
        var originPoint: CGPoint?
        
        enum CodingKeys: String, CodingKey {
            case numberOfBalls
            case originPoint
        }
    }
    
    public func saveState(restorationURL: URL) {
        let url = restorationURL.appendingPathComponent(BallManager.BallManagerPath)
        
        do {
            // Update the ball manager's state before we save it
            bmState!.numberOfBalls = numberOfBalls
            bmState!.originPoint = originPoint
            
            let data = try PropertyListEncoder().encode(self.bmState!)
            try data.write(to: url)
        }
        catch {
            print("Error saving ball manager state: \(error)")
        }
    }
    
    public func saveTurnState() {
        // Save the ball manager's turn state
        prevTurnState.numberOfBalls = numberOfBalls
        prevTurnState.originPoint = originPoint!
    }
    
    public func loadTurnState() -> Bool {
        if prevTurnState.numberOfBalls == 0 {
            return false
        }
        
        // Remove any new balls from the ball array
        let diff = numberOfBalls - prevTurnState.numberOfBalls
        if diff > 0 {
            for _ in 0...(diff - 1) {
                let _ = ballArray.popLast()
            }
        }
        
        // Load the ball manager's turn state
        numberOfBalls = prevTurnState.numberOfBalls
        originPoint! = prevTurnState.originPoint!
        
        // Reset the values so we don't try to reload the turn state again
        prevTurnState.numberOfBalls = 0
        prevTurnState.originPoint = CGPoint(x: 0, y: 0)
        
        return true
    }
    
    public func loadState(restorationURL: URL) -> Bool {
        do {
            let data = try Data(contentsOf: restorationURL)
            bmState = try PropertyListDecoder().decode(BallManagerState.self, from: data)
            return true
        }
        catch {
            print("Error loading ball manager state: \(error)")
            return false
        }
    }
    
    public func setBallsOnFire() {
        // Sets the balls on fire
        ballsOnFire = true
        for ball in ballArray {
            if false == ball.isResting {
                ball.setOnFire()
            }
        }
    }
    
    
    // MARK: Public functions
    required init(numBalls: Int, radius: CGFloat, restorationURL: URL) {
        ballRadius = radius
        
        let url = restorationURL.appendingPathComponent(BallManager.BallManagerPath)
        if false == loadState(restorationURL: url) {
            bmState = BallManagerState(numberOfBalls: numBalls, originPoint: nil)
        }

        numberOfBalls = bmState!.numberOfBalls
        originPoint = bmState!.originPoint
        
        for i in 1...numberOfBalls {
            let ball = BallItem()
            let size = CGSize(width: radius, height: radius)
            ball.initItem(num: i, size: size)
            ball.getNode().name! = "bm\(i)"
            ballArray.append(ball)
        }

        state = READY
    }
    
    required init() {
        // Empty constructor
    }
    
    public func setGroundHeight(height: CGFloat) {
        groundHeight = height
    }
    
    public func incrementState() {
        if DONE == state {
            state = READY
            // Reset this boolean to false
            ballsOnFire = false
            // Reset this boolean letting the shootBalls() function know whether or not the user swiped down and we should stop shooting
            swipedDown = false
            return
        }
        
        state += 1
    }
    
    public func checkNewArray() {
        let array = newBallArray.filter {
            // Tell the ball to return to the origin point and reset its physics bitmasks
            $0.stop()
            $0.moveBallTo(originPoint!)
            // Add the new ball to the ball manager's array
            self.ballArray.append($0)
            // This tells the filter to remove the ball from newBallArray
            return false
        }
        // Set the global newBallArray to an empty array now
        newBallArray = array
        
        // Update the number of balls the manager has
        numberOfBalls = ballArray.count
    }
    
    public func setOriginPoint(point: CGPoint) {
        originPoint = point
    }
    
    public func getOriginPoint() -> CGPoint {
        if let op = originPoint {
            return op
        }
        originPoint = ballArray[0].getNode().position
        return originPoint!
    }
    
    public func isReady() -> Bool {
        return (state == READY)
    }
    
    public func isShooting() -> Bool {
        return (state == SHOOTING)
    }
    
    public func isWaiting() -> Bool {
        return (state == WAITING)
    }
    
    public func isDone() -> Bool {
        return (state == DONE)
    }
    
    public func setDirection(point: CGPoint) {
        direction = point
    }
    
    public func addBall(ball: BallItem) {//, atPoint: CGPoint) {
        newBallArray.append(ball)
        // Update the ball name to avoid name collisions in the ball manager
        ball.getNode().name! = "bm\(ballArray.count + newBallArray.count)"
    }
    
    public func numRestingBalls() -> Int {
        return numberOfBalls - numBallsActive
    }
    
    public func shootBall() {
        let ball = ballArray[numBallsActive]
        ball.fire(point: direction!)
        if ballsOnFire {
            // If balls are already on fire then this ball needs to be on fire too
            ball.setOnFire()
        }
        numBallsActive += 1
    }
    
    public func shootBalls() {
        // Make sure that before we start shooting balls there aren't any lingering in this list
        /*
            There was a weird bug after refactoring BallManager: the game scene (ContinuousGameScene) would place balls from the
            ball manager on the ground (which the game would record as a collision) and the chain of events would fire and all
            balls in the BallManager's list would end up in the stoppedBalls list. When firing balls for the first time, it would
            process that list (in handleStoppedBalls) and tell them to stop and return to their origin point.
            This fixes that bug by ensuring that the stoppedBalls list is empty when starting to shoot balls.
        */
        stoppedBalls = []
        let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            // Check to see if the user swiped down while we were still shooting; we need to stop shooting if they did
            if self.allBallsFired() || self.swipedDown {
                timer.invalidate()
                // Increment state from SHOOTING to WAITING
                self.incrementState()
            }
            else {
                self.shootBall()
            }
        }
    }
    
    private func allBallsFired() -> Bool {
        return (false == ballArray[numberOfBalls - 1].isResting)
    }
    
    public func returnAllBalls() {
        if false == firstBallReturned {
            firstBallReturned = true
        }
        
        swipedDown = true
        
        for ball in ballArray {
            ball.getNode().physicsBody!.collisionBitMask = 0
            ball.getNode().physicsBody!.categoryBitMask = 0
            ball.getNode().physicsBody!.contactTestBitMask = 0
            ball.stop()
            ball.moveBallTo(originPoint!)
        }
        
        // shootBalls() will increment the ball manager's state if it's shooting
    }
    
    public func markBallInactive(name: String) {
        for ball in ballArray {
            if ball.node!.name == name {
                stoppedBalls.append(ball)
                ball.stop()
            }
        }
    }
    
    // This function should be called in the model's MID_TURN state
    public func handleStoppedBalls() {
        if stoppedBalls.count > 0 {
            // Pop this ball off the front of thel ist
            let ball = stoppedBalls.removeFirst()
            //ball.stop() // REMOVE ME
            if false == firstBallReturned {
                // The first ball hasn't been returned yet
                firstBallReturned = true
                var ballPosition = ball.node!.position
                if ballPosition.y > groundHeight {
                    // Ensure the ball is on the ground and not above it
                    ballPosition.y = groundHeight
                }
                originPoint = ball.node!.position
            }
            ball.moveBallTo(originPoint!)
        }
    }
    
    // This function should be called in the model's
    public func waitForBalls() {
        var activeBallInPlay = false
        for ball in ballArray {
            if false == ball.isResting {
                activeBallInPlay = true
                break
            }
        }
        if false == activeBallInPlay {
            // Increment state from WAITING to DONE
            incrementState()
            firstBallReturned = false
            numBallsActive = 0
            // Done waiting for balls
        }
        // Still waiting for balls
    }
    
    /* XXX REMOVE ME
    public func stopInactiveBalls() {
        if isReady() || isDone() {
            return
        }
                
        for ball in ballArray {
            if ball.isResting {
                continue
            }
            if false == ball.isActive {
                if false == firstBallReturned {
                    // Set the new origin point once a ball has returned
                    firstBallReturned = true
                    var ballPosition = ball.node!.position
                    if ballPosition.y > groundHeight {
                        // Ensure the ball is on the ground and not above it
                        ball.node!.position.y = groundHeight
                    }
                    originPoint = ball.node!.position
                }
                ball.moveBallTo(originPoint!)
            }
        }
        
        if isWaiting() {
            var activeBallInPlay = false
            for ball in ballArray {
                if ball.isActive || (false == ball.isResting) {
                    activeBallInPlay = true
                    break
                }
            }
            if false == activeBallInPlay {
                // Increment state from WAITING to DONE
                incrementState()
                firstBallReturned = false
                numBallsActive = 0
            }
        }
    }
    */
}
