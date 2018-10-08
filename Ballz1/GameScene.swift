//
//  GameScene.swift
//  Ballz1
//
//  Created by Gabriel Busto on 9/13/18.
//  Copyright © 2018 Self. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit
import CoreGraphics

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: Private attributes
    private var numberOfItems = Int(8)
    private var numberOfBalls = Int(10)
    private var margin : CGFloat?
    private var radius : CGFloat?
    
    private var groundNode : SKSpriteNode?
    private var ceilingNode : SKSpriteNode?
    private var leftWallNode : SKNode?
    private var rightWallNode : SKNode?
    
    private var fontName = "KohinoorBangla-Regular"

    private var scoreLabel : SKLabelNode?
    private var gameScore = Int(0)

    private var bestScoreLabel : SKLabelNode?
    private var bestScore = Int(0)

    private var ballManager : BallManager?
    private var itemGenerator : ItemGenerator?
    private var arrowNode : SKShapeNode?

    private var currentTouch : CGPoint?
    
    private var gameOver = false
    private var turnOver = true
    private var arrowIsShowing = false
    
    private var numTicksGap = 6
    private var numTicks = 0
    
    private var showedFFTutorial = false
    private var rightSwipeGesture : UISwipeGestureRecognizer?
    private var addedGesture = false

    private var sceneColor = UIColor.init(red: 20/255, green: 20/255, blue: 20/255, alpha: 1)
    private var marginColor = UIColor.init(red: 50/255, green: 50/255, blue: 50/255, alpha: 1)
    
    // Stuff for collisions
    private var categoryBitMask = UInt32(0b0001)
    private var contactTestBitMask = UInt32(0b0001)
    private var groundCategoryBitmask = UInt32(0b0101)
    
    // MVC: A view function; notifies the controller of contact between two bodies
    func didBegin(_ contact: SKPhysicsContact) {
        let nameA = contact.bodyA.node?.name!
        let nameB = contact.bodyB.node?.name!
        
        if (nameA?.starts(with: "ball"))! {
            if nameB! == "ground" {
                // Stop the ball at this exact point if it's the first ball to hit the ground
                ballManager!.markBallInactive(name: nameA!)
            }
            else if (nameB?.starts(with: "block"))! {
                // A block was hit
                itemGenerator!.hit(name: nameB!)
            }
            else if (nameB?.starts(with: "ball"))! {
                // A ball hit a ball item
                itemGenerator!.hit(name: nameB!)
            }
        }
        
        if (nameB?.starts(with: "ball"))! {
            if nameA! == "ground" {
                // Stop the ball at this exact point if it's the first ball to hit the ground
                ballManager!.markBallInactive(name: nameB!)
            }
            else if (nameA?.starts(with: "block"))! {
                // A block was hit
                itemGenerator!.hit(name: nameA!)
            }
            else if (nameA?.starts(with: "ball"))! {
                itemGenerator!.hit(name: nameA!)
            }
        }
    }
    
    // MARK: Override functions
    // MVC: A view function; initializes the view based on the view type (color schemes, themes, device type, etc)
    override func didMove(to view: SKView) {
        initWalls(view: view)
        initItemGenerator(view: view)
        initBallManager(view: view, numBalls: numberOfBalls)
        initArrowNode(view: view)
        initScoreLabel()
        initBestScoreLabel()
        
        rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight(_:)))
        rightSwipeGesture!.direction = .right
        rightSwipeGesture!.numberOfTouchesRequired = 1
        
        physicsWorld.contactDelegate = self
        self.backgroundColor = sceneColor
    }
    
    // MVC: View detects the touch; the code in this function should notify the GameSceneController to handle this event
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)

            if ballManager!.isReady() && itemGenerator!.isReady() {
                // Check to see if the touch is in the game area
                if inGame(point: point) {
                    let originPoint = ballManager!.getOriginPoint()
                    if (false == arrowIsShowing) && (false == gameOver) {
                        showArrow()
                    }
                    updateArrow(startPoint: originPoint, touchPoint: point)
                }
            }
        }
    }
    
    // MVC: View detects the touch; the code in this function should notify the GameSceneController to handle this event
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            if !inGame(point: point) {
                hideArrow()
            }
            else if ballManager!.isReady() && itemGenerator!.isReady() && arrowIsShowing {
                let originPoint = ballManager!.getOriginPoint()
                updateArrow(startPoint: originPoint, touchPoint: point)
            }
        }
    }
    
    // MVC: View detects the touch; the code in this function should notify the GameSceneController to handle this event
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            if ballManager!.isReady() && itemGenerator!.isReady() && arrowIsShowing {
                ballManager!.setDirection(point: point)
                ballManager!.incrementState()
            }
            /*
            else if gameOver {
                let scene = GameMenu(size: view!.bounds.size)
                
                scene.scaleMode = .aspectFill
                
                view!.ignoresSiblingOrder = true
                view!.showsFPS = true
                view!.showsNodeCount = true
                
                view!.presentScene(scene)
            }
            */
        }
        
        hideArrow()
    }
    
    // MVC: View detects the touch; the code in this function should notify the GameSceneController to handle this event
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    // MARK: Scene update
    // MVC: I think this code should simultaneously notify GameSceneController and also query the model
    override func update(_ currentTime: TimeInterval) {
        // MVC: turnOver is a Bool that is a game rule; should be in the game model
        //  The view queries the model to see if the turn is over and if it is:
        //  The model then tells the item generator to generate a new row, the ball manager to consolidate new balls, and update the score
        //  1. Reset the physics simulation,
        //  2. Clear the gestures
        //  3. Update the score label
        if turnOver {
            // MVC: Stuff regarding the physics world should stay in the view
            // Return physics simulation back to normal speed
            if self.physicsWorld.speed > 1.0 {
                self.physicsWorld.speed = 1.0
                numTicksGap = 6
            }
            
            // MVC: This should be in the view since gesture recognizers are a member of SKView
            // Clear the gesture recognizers for now
            view!.gestureRecognizers = []
            addedGesture = false
            
            // MVC: This code should be in the model; the controller updates the model and the model adds a row; the view should query the model to display the items
            // Generate a row
            itemGenerator!.generateRow(scene: self)
            // MVC: The ball manager checking its new ball array should also be in the model
            // In the event that we just collected a ball, it will not be at the origin point so move all balls to the origin point
            ballManager!.checkNewArray()
            // MVC: This score update should also be in the model and this view should query the model for the score update
            updateScore()
            // MVC: Model should update its turnOver variable
            turnOver = false
        }
        
        // MVC: This code should be in the model; checking to see if the game is over is part of the game rules
        // MVC: Or should it be in the controller to check whether or not the game is over?
        // After rows have been added, check to see if we can add any more rows
        if itemGenerator!.isReady() {
            if false == itemGenerator!.canAddRow(groundHeight: margin!) {
                // Game over!!!
                self.isPaused = true
                showGameOverNode()
                gameOver = true
            }
        }
        
        if ballManager!.isShooting() {
            if numTicks >= numTicksGap {
                ballManager!.shootBall()
                numTicks = 0
            }
            else {
                numTicks += 1
            }
        }
        
        if ballManager!.isShooting() || ballManager!.isWaiting() {
            if (false == addedGesture) {
                // If we haven't shown the fast forward tutorial yet, show it
                if (false == showedFFTutorial) {
                    showFFTutorial()
                }
                view!.gestureRecognizers = [rightSwipeGesture!]
                addedGesture = true
            }
            ballManager!.stopInactiveBalls()
        }
        
        if ballManager!.isDone() {
            turnOver = true
            ballManager!.incrementState()
        }
        
        let removedItems = itemGenerator!.removeItems(scene: self)
        
        // If the item generator removed an item from it's list, check to see if it removed a ball; if it does, it now needs to be moved under the BallManager
        for item in removedItems {
            if item.getNode().name!.starts(with: "ball") {
                let ball = item as! BallItem
                let newPoint = CGPoint(x: ball.getNode().position.x, y: margin! + radius!)
                ballManager!.addBall(ball: ball, atPoint: newPoint)
                print("Added ball \(ball.getNode().name!) to ball manager")
            }
        }
    }
    
    // MARK: Public functions
    // Handle a right swipe to fast forward
    // MVC: This function is called in the view
    @objc public func handleSwipeRight(_ sender: UISwipeGestureRecognizer) {
        let point = sender.location(in: view!)
        if inGame(point: point) {
            // MVC: Here we query the model to know its state and whether or not to fast forward the simulation
            // XXX This may be redundant; I think the right swipe gesture is only added to the view when this evaluates to true
            if ballManager!.isShooting() || ballManager!.isWaiting() {
                // MVC: The view should query the model to see if it has shown the fast forward tutorial already
                // If this is the first time we've shown the fast forward tutorial and the user swiped right.
                if (false == showedFFTutorial) {
                    // Remove the tutorial nodes from the scene
                    if let ffNode = self.childNode(withName: "ffTutorial") {
                        self.removeChildren(in: [ffNode])
                    }
                    if let ffLabel = self.childNode(withName: "ffLabel") {
                        self.removeChildren(in: [ffLabel])
                    }
                    
                    showedFFTutorial = true
                }
                // MVC: Speeding up the physics simulation remains in the view; this doesn't have to do with the model or the controller
                print("Speeding up physics simulation")
                if physicsWorld.speed < 3.0 {
                    physicsWorld.speed += 1
                    if (6 == numTicksGap) {
                        numTicksGap = 3
                    }
                    else if (3 == numTicksGap) {
                        numTicksGap = 1
                    }
                    flashSpeedupImage()
                }
            }
        }
    }
    
    // MARK: Private functions
    // MVC: Clearly a view functions
    private func inGame(point: CGPoint) -> Bool {
        return ((point.y < ceilingNode!.position.y) && (point.y > groundNode!.size.height))
    }
    
    // MVC: A view function
    private func initWalls(view: SKView) {
        margin = view.frame.height * 0.10
        
        initGround(view: view, margin: margin!)
        initCeiling(view: view, margin: margin!)
        initSideWalls(view: view, margin: margin!)
    }
    
    // MVC: A view function
    private func initGround(view: SKView, margin: CGFloat) {
        let size = CGSize(width: view.frame.width, height: margin)
        groundNode = SKSpriteNode(color: marginColor, size: size)
        groundNode?.anchorPoint = CGPoint(x: 0, y: 0)
        groundNode?.position = CGPoint(x: 0, y: 0)
        groundNode?.name = "ground"
        
        let startPoint = CGPoint(x: 0, y: margin)
        let endPoint = CGPoint(x: view.frame.width, y: margin)
        let physBody = SKPhysicsBody(edgeFrom: startPoint, to: endPoint)
        physBody.usesPreciseCollisionDetection = true
        physBody.restitution = 0
        physBody.angularDamping = 1
        physBody.linearDamping = 1
        physBody.categoryBitMask = groundCategoryBitmask
        physBody.contactTestBitMask = contactTestBitMask
        groundNode?.physicsBody = physBody
        
        self.addChild(groundNode!)
    }
    
    // MVC: A view function
    private func initCeiling(view: SKView, margin: CGFloat) {
        let size = CGSize(width: view.frame.width, height: view.safeAreaInsets.top + margin)
        ceilingNode = SKSpriteNode(color: marginColor, size: size)
        ceilingNode?.anchorPoint = CGPoint(x: 0, y: 0)
        ceilingNode?.position = CGPoint(x: 0, y: view.frame.height - view.safeAreaInsets.top - margin)
        ceilingNode?.name = "ceiling"
        ceilingNode?.zPosition = 101
        
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: view.frame.width, y: 0)
        let physBody = SKPhysicsBody(edgeFrom: startPoint, to: endPoint)
        physBody.angularDamping = 0
        physBody.linearDamping = 0
        physBody.restitution = 1
        physBody.friction = 0
        physBody.categoryBitMask = categoryBitMask
        physBody.contactTestBitMask = contactTestBitMask
        ceilingNode?.physicsBody = physBody
        
        self.addChild(ceilingNode!)
    }
    
    // MVC: A view function
    private func initSideWalls(view: SKView, margin: CGFloat) {
        let lwStartPoint = CGPoint(x: 1, y: margin)
        let lwEndPoint = CGPoint(x: 1, y: view.frame.height - margin)
        let leftWallEdge = SKPhysicsBody(edgeFrom: lwStartPoint, to: lwEndPoint)
        leftWallEdge.angularDamping = 0
        leftWallEdge.linearDamping = 0
        leftWallEdge.restitution = 1
        leftWallEdge.friction = 0
        leftWallEdge.categoryBitMask = categoryBitMask
        leftWallEdge.contactTestBitMask = contactTestBitMask
        leftWallNode = SKNode()
        leftWallNode?.physicsBody = leftWallEdge
        leftWallNode?.name = "wall"
        
        let rwStartPoint = CGPoint(x: view.frame.width, y: margin)
        let rwEndPoint = CGPoint(x: view.frame.width, y: view.frame.height - margin)
        let rightWallEdge = SKPhysicsBody(edgeFrom: rwStartPoint, to: rwEndPoint)
        rightWallEdge.angularDamping = 0
        rightWallEdge.linearDamping = 0
        rightWallEdge.restitution = 1
        rightWallEdge.friction = 0
        rightWallEdge.categoryBitMask = categoryBitMask
        rightWallEdge.contactTestBitMask = contactTestBitMask
        rightWallNode = SKNode()
        rightWallNode?.physicsBody = rightWallEdge
        rightWallNode?.name = "wall"
        
        self.addChild(leftWallNode!)
        self.addChild(rightWallNode!)
    }
    
    // MVC: A model function
    private func initItemGenerator(view: SKView) {
        itemGenerator = ItemGenerator()
        itemGenerator?.initGenerator(view: view, numBalls: numberOfBalls, numItems: numberOfItems, ceiling: ceilingNode!.position.y, ground: margin!)
    }
    
    // MVC: A model function
    private func initBallManager(view: SKView, numBalls: Int) {
        radius = CGFloat(view.frame.width * 0.018)
        ballManager = BallManager()
        let position = CGPoint(x: view.frame.midX, y: margin! + radius!)
        ballManager!.initBallManager(scene: self, generator: itemGenerator!, numBalls: numBalls, position: position, radius: radius!)
        ballManager!.addBalls()
    }
    
    // MVC: A view function; anything with the arrow node is a view function for now (until we allow the user to upgrade the arrow pointer style)
    private func initArrowNode(view: SKView) {
        arrowNode = SKShapeNode()
    }
    
    // MVC: A view function
    private func updateArrow(startPoint: CGPoint, touchPoint: CGPoint) {
        let maxOffset = CGFloat(200)
        
        let slope = calcSlope(originPoint: startPoint, touchPoint: touchPoint)
        let intercept = calcYIntercept(point: touchPoint, slope: slope)
        
        var newX = CGFloat(0)
        var newY = CGFloat(0)
        
        if (slope >= 1) || (slope <= -1) {
            newY = touchPoint.y + maxOffset
            newX = (newY - intercept) / slope
        }
        else if (slope < 1) && (slope > -1) {
            if (slope < 0) {
                newX = touchPoint.x - maxOffset
            }
            else if (slope > 0) {
                newX = touchPoint.x + maxOffset
            }
            newY = (slope * newX) + intercept
        }
        
        let endPoint = CGPoint(x: newX, y: newY)
        
        let pattern: [CGFloat] = [10, 10]
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        let dashedPath = path.copy(dashingWithPhase: 0, lengths: pattern)
        
        let color = UIColor(red: 119/255, green: 136/255, blue: 153/255, alpha: 1)
        arrowNode!.path = dashedPath
        arrowNode!.strokeColor = color
        arrowNode!.lineWidth = 4
    }
    
    // MVC: A view function
    private func showArrow() {
        if (false == arrowIsShowing) {
            self.addChild(arrowNode!)
            arrowIsShowing = true
        }
    }
    
    // MVC: A view function
    private func hideArrow() {
        if arrowIsShowing {
            self.removeChildren(in: [arrowNode!])
            arrowIsShowing = false
        }
    }
    
    // MVC: A view function (should be put in a separate file)
    private func calcSlope(originPoint: CGPoint, touchPoint: CGPoint) -> CGFloat {
        let rise = touchPoint.y - originPoint.y
        let run  = touchPoint.x - originPoint.x
        
        return CGFloat(rise / run)
    }
    
    // MVC: A view function (should be put in a separate file)
    private func calcYIntercept(point: CGPoint, slope: CGFloat) -> CGFloat {
        // y = mx + b <- We want to find 'b'
        // (point.y - (point.x * slope)) = b
        let intercept = point.y - (point.x * slope)
        
        return intercept
    }
    
    // MVC: A view function
    private func showGameOverNode() {
        let gameOverNode = SKSpriteNode(color: .darkGray, size: scene!.size)
        gameOverNode.alpha = 0.9
        gameOverNode.zPosition = 105
        gameOverNode.position = CGPoint(x: 0, y: 0)
        gameOverNode.anchorPoint = CGPoint(x: 0, y: 0)
        self.addChild(gameOverNode)
        
        let fontSize = view!.frame.height * 0.2
        let label = SKLabelNode()
        label.zPosition = 106
        label.position = CGPoint(x: view!.frame.midX, y: view!.frame.midY + (fontSize / 2))
        label.fontSize = fontSize
        label.fontName = fontName
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.color = .white
        label.text = "Game"
        
        let label2 = SKLabelNode()
        label2.zPosition = 106
        label2.position = CGPoint(x: view!.frame.midX, y: view!.frame.midY - (fontSize / 2))
        label2.fontSize = fontSize
        label2.fontName = fontName
        label2.verticalAlignmentMode = .center
        label2.horizontalAlignmentMode = .center
        label2.color = .white
        label2.text = "Over"
        
        let label3 = SKLabelNode()
        label3.zPosition = 106
        label3.position = CGPoint(x: view!.frame.midX, y: view!.frame.midY - (fontSize * 1.5))
        label3.fontSize = fontSize * 0.2
        label3.fontName = fontName
        label3.verticalAlignmentMode = .center
        label3.horizontalAlignmentMode = .center
        label3.color = .white
        label3.text = "Touch to restart"
        
        self.addChild(label)
        self.addChild(label2)
        self.addChild(label3)
    }
    
    // MVC: A view function (but the score is initialized in the model)
    private func initScoreLabel() {
        let pos = CGPoint(x: view!.frame.midX, y: ceilingNode!.size.height / 2)
        scoreLabel = SKLabelNode()
        scoreLabel!.zPosition = 103
        scoreLabel!.position = pos
        scoreLabel!.fontSize = margin! * 0.50
        scoreLabel!.fontName = fontName
        scoreLabel!.verticalAlignmentMode = .center
        scoreLabel!.horizontalAlignmentMode = .center
        scoreLabel!.text = "0"
        ceilingNode!.addChild(scoreLabel!)
    }
    
    // MVC: A view function (but the high score is initialized in the model)
    // XXX Should rename anything with bestScore to highScore
    private func initBestScoreLabel() {
        let pos = CGPoint(x: ceilingNode!.size.width * 0.02, y: ceilingNode!.size.height / 2)
        bestScoreLabel = SKLabelNode()
        bestScoreLabel!.zPosition = 103
        bestScoreLabel!.position = pos
        bestScoreLabel!.fontName = fontName
        bestScoreLabel!.fontSize = margin! * 0.30
        bestScoreLabel!.verticalAlignmentMode = .center
        bestScoreLabel!.horizontalAlignmentMode = .left
        bestScoreLabel!.text = "Best: \(gameScore)"
        ceilingNode!.addChild(bestScoreLabel!)
    }

    // MVC: A model function
    private func updateScore() {
        gameScore += 1
        scoreLabel!.text = "\(gameScore)"
        
        if gameScore > bestScore {
            bestScoreLabel!.text = "Best: \(gameScore)"
            bestScore = gameScore
        }
    }
    
    // MVC: A view function
    private func flashSpeedupImage() {
        let color = UIColor(red: 119/255, green: 136/255, blue: 153/255, alpha: 1)
        let pos = CGPoint(x: self.view!.frame.midX, y: self.view!.frame.midY)
        let size = CGSize(width: self.view!.frame.width * 0.8, height: self.view!.frame.width * 0.8)
        let imageNode = SKSpriteNode(imageNamed: "fast_forward.png")
        imageNode.alpha = 0
        imageNode.position = pos
        imageNode.size = size
        
        let label = SKLabelNode(fontNamed: fontName)
        label.fontSize = 50
        label.fontColor = color
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        if (2.0 == physicsWorld.speed) {
            label.text = "x2"
        }
        else if (3.0 == physicsWorld.speed) {
            label.text = "x3"
        }
        imageNode.addChild(label)
        
        self.addChild(imageNode)
        
        let action1 = SKAction.fadeAlpha(to: 0.5, duration: 0.2)
        let action2 = SKAction.fadeAlpha(to: 0, duration: 0.2)
        
        imageNode.run(SKAction.sequence([action1, action2, action1, action2, action1, action2])) {
            self.removeChildren(in: [imageNode])
        }
    }

    // MVC: A view function
    // Shows the user how to fast forward the simulation
    private func showFFTutorial() {
        let size = CGSize(width: view!.frame.width * 0.15, height: view!.frame.width * 0.15)
        let startPoint = CGPoint(x: view!.frame.width * 0.35, y: view!.frame.midY)
        let endPoint = CGPoint(x: view!.frame.width * 0.65, y: view!.frame.midY)
        
        let ffNode = SKSpriteNode(imageNamed: "touch_image.png")
        ffNode.position = startPoint
        ffNode.size = size
        ffNode.alpha = 1
        ffNode.name = "ffTutorial"
        self.addChild(ffNode)
        
        let action1 = SKAction.move(to: endPoint, duration: 0.8)
        let action2 = SKAction.move(to: startPoint, duration: 0.1)
        
        let label = SKLabelNode(fontNamed: fontName)
        label.fontColor = .white
        label.fontSize = 20
        label.text = "Fast forward"
        label.name = "ffLabel"
        label.position = CGPoint(x: view!.frame.midX, y: view!.frame.midY * 0.80)
        self.addChild(label)
        
        ffNode.run(SKAction.sequence([action1, action2, action1, action2, action1])) {
            self.removeChildren(in: [ffNode, label])
        }
    }
}
