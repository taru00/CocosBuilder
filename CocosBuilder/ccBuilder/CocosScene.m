/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2011 Viktor Lidholt
 * Copyright (c) 2012 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "CocosScene.h"
#import "CCBGlobals.h"
#import "CocosBuilderAppDelegate.h"
#import "CCBReaderInternalV1.h"
#import "NodeInfo.h"
#import "PlugInManager.h"
#import "PlugInNode.h"
#import "RulersLayer.h"
#import "GuidesLayer.h"
#import "NotesLayer.h"
#import "CCBTransparentWindow.h"
#import "CCBTransparentView.h"
#import "PositionPropertySetter.h"
#import "CCBGLView.h"
#import "MainWindow.h"
#import "CCNode+NodeInfo.h"
#import "SequencerHandler.h"
#import "SequencerSequence.h"
#import "SequencerNodeProperty.h"
#import "SequencerKeyframe.h"
#import "CCScale9Sprite.h"

#define kCCBSelectionOutset 3

static CocosScene* sharedCocosScene;

@implementation CocosScene

@synthesize rootNode;
@synthesize isMouseTransforming;
@synthesize scrollOffset;
@synthesize currentTool;
@synthesize guideLayer;
@synthesize rulerLayer;
@synthesize notesLayer;

+(id) sceneWithAppDelegate:(CocosBuilderAppDelegate*)app
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	CocosScene *layer = [[[CocosScene alloc] initWithAppDelegate:app] autorelease];
    sharedCocosScene = layer;
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

+ (CocosScene*) cocosScene
{
    return sharedCocosScene;
}

-(void) setupEditorNodes
{
    // Rulers
    rulerLayer = [RulersLayer node];
    [self addChild:rulerLayer z:6];
    
    // Guides
    guideLayer = [GuidesLayer node];
    [self addChild:guideLayer z:3];
    
    // Sticky notes
    notesLayer = [NotesLayer node];
    [self addChild:notesLayer z:5];
    
    // Selection layer
    selectionLayer = [CCLayer node];
    [self addChild:selectionLayer z:4];
    
    // Border layer
    borderLayer = [CCLayer node];
    [self addChild:borderLayer z:1];
    
    ccColor4B borderColor = ccc4(128, 128, 128, 180);
    
    borderBottom = [CCLayerColor layerWithColor:borderColor];
    borderTop = [CCLayerColor layerWithColor:borderColor];
    borderLeft = [CCLayerColor layerWithColor:borderColor];
    borderRight = [CCLayerColor layerWithColor:borderColor];
    
    [borderLayer addChild:borderBottom];
    [borderLayer addChild:borderTop];
    [borderLayer addChild:borderLeft];
    [borderLayer addChild:borderRight];
    
    borderDevice = [CCSprite node];
    [borderLayer addChild:borderDevice z:1];
    
    // Gray background
    bgLayer = [CCLayerColor layerWithColor:ccc4(128, 128, 128, 255) width:4096 height:4096];
    bgLayer.position = ccp(0,0);
    bgLayer.anchorPoint = ccp(0,0);
    [self addChild:bgLayer z:-1];
    
    // Black content layer
    stageBgLayer = [CCLayerColor layerWithColor:ccc4(0, 0, 0, 255) width:0 height:0];
    stageBgLayer.anchorPoint = ccp(0.5,0.5);
    stageBgLayer.ignoreAnchorPointForPosition = NO;
    [self addChild:stageBgLayer z:0];
    
    contentLayer = [CCLayer node];
    [stageBgLayer addChild:contentLayer];
}

- (void) setStageBorder:(int)type
{
    borderDevice.visible = NO;
    
    if (stageBgLayer.contentSize.width == 0 || stageBgLayer.contentSize.height == 0)
    {
        type = kCCBBorderNone;
        stageBgLayer.visible = NO;
    }
    else
    {
        stageBgLayer.visible = YES;
    }
    
    if (type == kCCBBorderDevice)
    {
        [borderBottom setOpacity:255];
        [borderTop setOpacity:255];
        [borderLeft setOpacity:255];
        [borderRight setOpacity:255];
        
        CCTexture2D* deviceTexture = NULL;
        BOOL rotateDevice = NO;
        
        int devType = [appDelegate orientedDeviceTypeForSize:stageBgLayer.contentSize];
        if (devType == kCCBCanvasSizeIPhonePortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-iphone.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeIPhoneLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-iphone.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeIPadPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-ipad.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeIPadLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-ipad.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeAndroidXSmallPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-xsmall.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeAndroidXSmallLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-xsmall.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeAndroidSmallPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-small.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeAndroidSmallLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-small.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeAndroidMediumPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-medium.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeAndroidMediumLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-medium.png"];
            rotateDevice = YES;
        }
        
        if (deviceTexture)
        {
            if (rotateDevice) borderDevice.rotation = 90;
            else borderDevice.rotation = 0;
            
            borderDevice.texture = deviceTexture;
            borderDevice.textureRect = CGRectMake(0, 0, deviceTexture.contentSize.width, deviceTexture.contentSize.height);
            
            borderDevice.visible = YES;
        }
        borderLayer.visible = YES;
    }
    else if (type == kCCBBorderTransparent)
    {
        [borderBottom setOpacity:180];
        [borderTop setOpacity:180];
        [borderLeft setOpacity:180];
        [borderRight setOpacity:180];
        
        borderLayer.visible = YES;
    }
    else if (type == kCCBBorderOpaque)
    {
        [borderBottom setOpacity:255];
        [borderTop setOpacity:255];
        [borderLeft setOpacity:255];
        [borderRight setOpacity:255];
        borderLayer.visible = YES;
    }
    else
    {
        borderLayer.visible = NO;
    }
    
    stageBorderType = type;
    
    [appDelegate updateCanvasBorderMenu];
}

- (int) stageBorder
{
    return stageBorderType;
}

- (void) setupDefaultNodes
{
}

#pragma mark Stage properties

- (void) setStageSize: (CGSize) size centeredOrigin:(BOOL)centeredOrigin
{
    stageBgLayer.contentSize = size;
    if (centeredOrigin) contentLayer.position = ccp(size.width/2, size.height/2);
    else contentLayer.position = ccp(0,0);
    
    [self setStageBorder:stageBorderType];
    
    if (renderedScene)
    {
        [self removeChild:renderedScene cleanup:YES];
        renderedScene = NULL;
    }
    
    if (size.width > 0 && size.height > 0 && size.width <= 1024 && size.height <= 1024)
    {
        renderedScene = [CCRenderTexture renderTextureWithWidth:size.width height:size.height];
        renderedScene.anchorPoint = ccp(0.5f,0.5f);
        [self addChild:renderedScene];
    }
}

- (CGSize) stageSize
{
    return stageBgLayer.contentSize;
}

- (BOOL) centeredOrigin
{
    return (contentLayer.position.x != 0);
}

- (void) setStageZoom:(float) zoom
{
    float zoomFactor = zoom/stageZoom;
    
    scrollOffset = ccpMult(scrollOffset, zoomFactor);
    
    stageBgLayer.scale = zoom;
    borderDevice.scale = zoom;
    
    stageZoom = zoom;
}

- (float) stageZoom
{
    return stageZoom;
}

#pragma mark Extra properties

- (void) setupExtraPropsForNode:(CCNode*) node
{
    [node setExtraProp:[NSNumber numberWithInt:-1] forKey:@"tag"];
    [node setExtraProp:[NSNumber numberWithBool:YES] forKey:@"lockedScaleRatio"];
    
    [node setExtraProp:@"" forKey:@"customClass"];
    [node setExtraProp:[NSNumber numberWithInt:0] forKey:@"memberVarAssignmentType"];
    [node setExtraProp:@"" forKey:@"memberVarAssignmentName"];
    
    [node setExtraProp:[NSNumber numberWithBool:YES] forKey:@"isExpanded"];
}

#pragma mark Replacing content

- (void) replaceRootNodeWith:(CCNode*)node
{
    CCBGlobals* g = [CCBGlobals globals];
    
    [contentLayer removeChild:rootNode cleanup:YES];
    
    self.rootNode = node;
    g.rootNode = node;
    
    if (!node) return;
    
    [contentLayer addChild:node];
}

#pragma mark Handle selections

- (BOOL) selectedNodeHasReadOnlyProperty:(NSString*)prop
{
    CCNode* selectedNode = appDelegate.selectedNode;
    
    if (!selectedNode) return NO;
    NodeInfo* info = selectedNode.userObject;
    PlugInNode* plugIn = info.plugIn;
    
    NSDictionary* propInfo = [plugIn.nodePropertiesDict objectForKey:prop];
    return [[propInfo objectForKey:@"readOnly"] boolValue];
}

- (void) updateSelection
{
    NSArray* nodes = appDelegate.selectedNodes;
    
    // Clear selection
    [selectionLayer removeAllChildrenWithCleanup:YES];
    
    if (nodes.count > 0)
    {
        for (CCNode* node in nodes)
        {
            CCNode* parent = node.parent;
            
            // Add centerpoint
            CGPoint center = [parent convertToWorldSpace: node.position];
            CCSprite* selmarkCenter = [CCSprite spriteWithFile:@"select-pt.png"];
            selmarkCenter.position = center;
            [selectionLayer addChild:selmarkCenter z:1];
            
            CGPoint minCorner = center;
            
            if (node.contentSize.width > 0 && node.contentSize.height > 0)
            {
                CGAffineTransform transform = [node nodeToWorldTransform];
                float angleRad = -(atan2(transform.b, transform.a));
                float angle = angleRad/(M_PI*2)*360;
                
                // Selection corners in world space
                CGPoint bl = [node convertToWorldSpace: ccp(0,0)];
                CGPoint br = [node convertToWorldSpace: ccp(node.contentSize.width,0)];
                CGPoint tl = [node convertToWorldSpace: ccp(0,node.contentSize.height)];
                CGPoint tr = [node convertToWorldSpace: ccp(node.contentSize.width,node.contentSize.height)];
                
                // Width & height of selection
                float width = (int)ccpLength(ccpSub(br, bl));
                float height = (int)ccpLength(ccpSub(tl, bl));
                
                // Check if selection is mirrored
                CGPoint posRaw = bl;
                if ([self isLocalCoordinateSystemFlipped:node]) posRaw = tl;
                
                // Round so it is always displayed sharply
                CGPoint pos = ccpSub(posRaw, ccpRotateByAngle(ccp(kCCBSelectionOutset,kCCBSelectionOutset), CGPointZero, -angleRad));
                
                if (angle == 0)
                {
                    pos = ccp((int)pos.x, (int)pos.y);
                }
                
                // Create a sprite for the selection
                CCScale9Sprite* sel = [CCScale9Sprite spriteWithFile:@"sel-frame.png" capInsets:CGRectMake(8, 8, 8, 8)];
                sel.anchorPoint = ccp(0,0);
                sel.rotation = angle;
                sel.position = pos;
                sel.preferedSize = CGSizeMake(width + kCCBSelectionOutset * 2, height + kCCBSelectionOutset * 2);
                [selectionLayer addChild:sel];
                
                minCorner.x = MIN(minCorner.x, bl.x);
                minCorner.x = MIN(minCorner.x, br.x);
                minCorner.x = MIN(minCorner.x, tl.x);
                minCorner.x = MIN(minCorner.x, tr.x);
                
                minCorner.y = MIN(minCorner.y, bl.y);
                minCorner.y = MIN(minCorner.y, br.y);
                minCorner.y = MIN(minCorner.y, tl.y);
                minCorner.y = MIN(minCorner.y, tr.y);
            }
            
            if (minCorner.x < 10+15) minCorner.x = 10+15;
            if (minCorner.y < 36+15) minCorner.y = 36+15;
            if (minCorner.x > self.contentSize.width - 28*3+6) minCorner.x = self.contentSize.width - 28*3+6;
            if (minCorner.y > self.contentSize.height+6) minCorner.y = self.contentSize.height+6;
            
            minCorner.x = (int)minCorner.x;
            minCorner.y = (int)minCorner.y;
        }
    }
}

- (void) selectBehind
{
    if (currentNodeAtSelectionPtIdx < 0) return;
    
    currentNodeAtSelectionPtIdx -= 1;
    if (currentNodeAtSelectionPtIdx < 0)
    {
        currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    }
    
    [appDelegate setSelectedNodes:[NSArray arrayWithObject:[nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx]]];
}

#pragma mark Handle mouse input

- (CGPoint) convertToDocSpace:(CGPoint)viewPt
{
    return [contentLayer convertToNodeSpace:viewPt];
}

- (CGPoint) convertToViewSpace:(CGPoint)docPt
{
    return [contentLayer convertToWorldSpace:docPt];
}

- (NSString*) positionPropertyForSelectedNode
{
    NodeInfo* info = appDelegate.selectedNode.userObject;
    PlugInNode* plugIn = info.plugIn;
    
    return plugIn.positionProperty;
}

- (CGPoint) selectedNodePos
{
    if (!appDelegate.selectedNode) return CGPointZero;
    
    return NSPointToCGPoint([PositionPropertySetter positionForNode:appDelegate.selectedNode prop:[self positionPropertyForSelectedNode]]);
}

- (int) transformHandleUnderPt:(CGPoint)pt
{
    for (CCNode* node in appDelegate.selectedNodes)
    {
        CGPoint bl = [node convertToWorldSpace: ccp(0,0)];
        CGPoint br = [node convertToWorldSpace: ccp(node.contentSize.width,0)];
        CGPoint tl = [node convertToWorldSpace: ccp(0,node.contentSize.height)];
        CGPoint tr = [node convertToWorldSpace: ccp(node.contentSize.width,node.contentSize.height)];
        
        transformScalingNode = node;
        if (ccpDistance(pt, bl) < 5) return kCCBTransformHandleScale;
        if (ccpDistance(pt, br) < 5) return kCCBTransformHandleScale;
        if (ccpDistance(pt, tl) < 5) return kCCBTransformHandleScale;
        if (ccpDistance(pt, tr) < 5) return kCCBTransformHandleScale;
    }
    
    transformScalingNode = NULL;
    return kCCBTransformHandleNone;
}

- (void) nodesUnderPt:(CGPoint)pt rootNode:(CCNode*) node nodes:(NSMutableArray*)nodes
{
    if (!node) return;
    
    NodeInfo* parentInfo = node.parent.userObject;
    PlugInNode* parentPlugIn = parentInfo.plugIn;
    
    if (parentPlugIn && !parentPlugIn.canHaveChildren) return;
    
    CGRect hitRect = [node boundingBox];
    
    // Extend the hit area if it's too small
    if (node.contentSize.width < 10)
    {
        hitRect.origin.x -= 5;
        hitRect.size.width += 10;
    }
    
    if (node.contentSize.height < 10)
    {
        hitRect.origin.y -= 5;
        hitRect.size.height += 10;
    }
    
    CCNode* parent = node.parent;
    CGPoint ptLocal = [parent convertToNodeSpace:pt];
    
    if (CGRectContainsPoint(hitRect, ptLocal))
    {
        [nodes addObject:node];
    }
    
    // Visit children
    for (int i = 0; i < [node.children count]; i++)
    {
        [self nodesUnderPt:pt rootNode:[node.children objectAtIndex:i] nodes:nodes];
    }
    
}

- (BOOL) isLocalCoordinateSystemFlipped:(CCNode*)node
{
    // TODO: Can this be done more efficiently?
    BOOL isMirroredX = NO;
    BOOL isMirroredY = NO;
    CCNode* nodeMirrorCheck = node;
    while (nodeMirrorCheck != rootNode && nodeMirrorCheck != NULL)
    {
        if (nodeMirrorCheck.scaleY < 0) isMirroredY = !isMirroredY;
        if (nodeMirrorCheck.scaleX < 0) isMirroredX = !isMirroredX;
        nodeMirrorCheck = nodeMirrorCheck.parent;
    }
    
    return (isMirroredX ^ isMirroredY);
}

- (BOOL) ccMouseDown:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return YES;
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    if ([notesLayer mouseDown:pos event:event]) return YES;
    if ([guideLayer mouseDown:pos event:event]) return YES;
    
    mouseDownPos = pos;
    
    // Handle grab tool
    if (currentTool == kCCBToolGrab || ([event modifierFlags] & NSCommandKeyMask))
    {
        [[NSCursor closedHandCursor] push];
        isPanning = YES;
        panningStartScrollOffset = scrollOffset;
        return YES;
    }
    
    // Find out which objects were clicked
    
    // Transform handles
    int th = [self transformHandleUnderPt:pos];
    if (th == kCCBTransformHandleScale && appDelegate.selectedNode != rootNode)
    {
        if ([event modifierFlags] & NSAlternateKeyMask)
        {
            // Start rotation transform (instead of scale)
            currentMouseTransform = kCCBTransformHandleRotate;
            transformStartRotation = transformScalingNode.rotation;
            return YES;
        }
        else
        {
            // Start scale transform
            currentMouseTransform = kCCBTransformHandleScale;
            transformStartScaleX = [PositionPropertySetter scaleXForNode:transformScalingNode prop:@"scale"];
            transformStartScaleY = [PositionPropertySetter scaleYForNode:transformScalingNode prop:@"scale"];
            return YES;
        }
    }
    
    // Clicks inside objects
    [nodesAtSelectionPt removeAllObjects];
    [self nodesUnderPt:pos rootNode:rootNode nodes:nodesAtSelectionPt];
    currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    
    currentMouseTransform = kCCBTransformHandleNone;
    
    if (currentNodeAtSelectionPtIdx >= 0)
    {
        currentMouseTransform = kCCBTransformHandleDownInside;
    }
    else
    {
        // No clicked node
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Ignore
            return YES;
        }
        else
        {
            // Deselect
            appDelegate.selectedNodes = NULL;
        }
    }
    
    return YES;
}

- (BOOL) ccMouseDragged:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return YES;
    [self mouseMoved:event];
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    if ([notesLayer mouseDragged:pos event:event]) return YES;
    if ([guideLayer mouseDragged:pos event:event]) return YES;
    
    //
    
    if (currentMouseTransform == kCCBTransformHandleDownInside)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Add to selection
            NSMutableArray* modifiedSelection = [NSMutableArray arrayWithArray: appDelegate.selectedNodes];
            
            if (![modifiedSelection containsObject:clickedNode])
            {
                [modifiedSelection addObject:clickedNode];
            }
            appDelegate.selectedNodes = modifiedSelection;
        }
        else if (![appDelegate.selectedNodes containsObject:clickedNode])
        {
            // Replace selection
            appDelegate.selectedNodes = [NSArray arrayWithObject:clickedNode];
        }
        
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            CGPoint pos = NSPointToCGPoint([PositionPropertySetter positionForNode:selectedNode prop:@"position"]);
            
            selectedNode.transformStartPosition = [selectedNode.parent convertToWorldSpace:pos];
        }
    
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            NSLog(@"transformStartPosition: (%f,%f)",selectedNode.transformStartPosition.x, selectedNode.transformStartPosition.y);
        }
    
        if (appDelegate.selectedNode != rootNode)
        {
            currentMouseTransform = kCCBTransformHandleMove;
        }
    }
    
    if (currentMouseTransform == kCCBTransformHandleMove)
    {
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            float xDelta = (int)(pos.x - mouseDownPos.x);
            float yDelta = (int)(pos.y - mouseDownPos.y);
            
            CGSize parentSize = [PositionPropertySetter getParentSize:selectedNode];
            
            // Swap axis for relative positions
            int positionType = [PositionPropertySetter positionTypeForNode:selectedNode prop:@"position"];
            if (positionType == kCCBPositionTypeRelativeBottomRight)
            {
                xDelta = -xDelta;
            }
            else if (positionType == kCCBPositionTypeRelativeTopLeft)
            {
                yDelta = -yDelta;
            }
            else if (positionType == kCCBPositionTypeRelativeTopRight)
            {
                xDelta = -xDelta;
                yDelta = -yDelta;
            }
            else if (positionType == kCCBPositionTypePercent)
            {
                // Handle percental positions
                if (parentSize.width > 0)
                {
                    xDelta = (xDelta/parentSize.width)*100.0f;
                }
                else
                {
                    xDelta = 0;
                }
                
                if (parentSize.height > 0)
                {
                    yDelta = (yDelta/parentSize.height)*100.0f;
                }
                else
                {
                    yDelta = 0;
                }
            }
            
            CGPoint newPos = ccp(selectedNode.transformStartPosition.x+xDelta, selectedNode.transformStartPosition.y+yDelta);
            
            // Snap to guides
            
            /*
            if (appDelegate.showGuides && appDelegate.snapToGuides)
            {
                // Convert to absolute position (conversion need to happen in node space)
                CGPoint newAbsPos = [selectedNode.parent convertToNodeSpace:newPos];
                
                newAbsPos = NSPointToCGPoint([PositionPropertySetter calcAbsolutePositionFromRelative:NSPointFromCGPoint(newAbsPos) type:positionType parentSize:parentSize]);
                
                newAbsPos = [selectedNode.parent convertToWorldSpace:newAbsPos];
                
                // Perform snapping (snapping happens in world space)
                newAbsPos = [guideLayer snapPoint:newAbsPos];
                
                // Convert back to relative (conversion need to happen in node space)
                newAbsPos = [selectedNode.parent convertToNodeSpace:newAbsPos];
                
                newAbsPos = NSPointToCGPoint([PositionPropertySetter calcRelativePositionFromAbsolute:NSPointFromCGPoint(newAbsPos) type:positionType parentSize:parentSize]);
                
                newPos = [selectedNode.parent convertToWorldSpace:newAbsPos];
            }
             */
            
        
            CGPoint newLocalPos = [selectedNode.parent convertToNodeSpace:newPos];
        
            NSLog(@"newLocalPos: (%f,%f)", newLocalPos.x, newLocalPos.y);
            
            [appDelegate saveUndoStateWillChangeProperty:@"position"];
            
            [PositionPropertySetter setPosition:NSPointFromCGPoint(newLocalPos) forNode:selectedNode prop:@"position"];
        }
        [appDelegate refreshProperty:@"position"];
    }
    else if (currentMouseTransform == kCCBTransformHandleScale)
    {
        CGPoint nodePos = [transformScalingNode.parent convertToWorldSpace:transformScalingNode.position];
        
        CGPoint deltaStart = ccpSub(nodePos, mouseDownPos);
        CGPoint deltaNew = ccpSub(nodePos, pos);
        
        // Rotate deltas
        CGPoint anglePos0 = [transformScalingNode convertToWorldSpace:ccp(0,0)];
        CGPoint anglePos1 = [transformScalingNode convertToWorldSpace:ccp(1,0)];
        CGPoint angleVector = ccpSub(anglePos1, anglePos0);
        
        float angle = atan2f(angleVector.y, angleVector.x);
        
        deltaStart = ccpRotateByAngle(deltaStart, CGPointZero, -angle);
        deltaNew = ccpRotateByAngle(deltaNew, CGPointZero, -angle);
        
        // Calculate new scale
        float xScaleNew = (deltaNew.x  * transformStartScaleX)/deltaStart.x;
        float yScaleNew = (deltaNew.y  * transformStartScaleY)/deltaStart.y;
        
        // Set new scale
        [appDelegate saveUndoStateWillChangeProperty:@"scale"];
        
        int type = [PositionPropertySetter scaledFloatTypeForNode:transformScalingNode prop:@"scale"];
        [PositionPropertySetter setScaledX:xScaleNew Y:yScaleNew type:type forNode:transformScalingNode prop:@"scale"];
        
        [appDelegate refreshProperty:@"scale"];
    }
    else if (currentMouseTransform == kCCBTransformHandleRotate)
    {
        CGPoint nodePos = [transformScalingNode.parent convertToWorldSpace:transformScalingNode.position];
        
        CGPoint handleAngleVectorStart = ccpSub(nodePos, mouseDownPos);
        CGPoint handleAngleVectorNew = ccpSub(nodePos, pos);
        
        float handleAngleRadStart = atan2f(handleAngleVectorStart.y, handleAngleVectorStart.x);
        float handleAngleRadNew = atan2f(handleAngleVectorNew.y, handleAngleVectorNew.x);
        
        float deltaRotationRad = handleAngleRadNew - handleAngleRadStart;
        float deltaRotation = -(deltaRotationRad/(2*M_PI))*360;
        
        if ([self isLocalCoordinateSystemFlipped:transformScalingNode.parent])
        {
            deltaRotation = -deltaRotation;
        }
        
        float newRotation = fmodf(transformStartRotation + deltaRotation, 360);
        
        [appDelegate saveUndoStateWillChangeProperty:@"rotation"];
        transformScalingNode.rotation = newRotation;
        [appDelegate refreshProperty:@"rotation"];
    }
    else if (isPanning)
    {
        CGPoint delta = ccpSub(pos, mouseDownPos);
        scrollOffset = ccpAdd(panningStartScrollOffset, delta);
    }
    
    return YES;
}

- (void) updateAnimateablePropertyValue:(id)value propName:(NSString*)propertyName type:(int)type
{
    CCNode* selectedNode = appDelegate.selectedNode;
    
    NodeInfo* nodeInfo = selectedNode.userObject;
    PlugInNode* plugIn = nodeInfo.plugIn;
    SequencerHandler* sh = [SequencerHandler sharedHandler];
    
    if ([plugIn isAnimatableProperty:propertyName])
    {
        SequencerSequence* seq = sh.currentSequence;
        int seqId = seq.sequenceId;
        SequencerNodeProperty* seqNodeProp = [selectedNode sequenceNodeProperty:propertyName sequenceId:seqId];
        
        if (seqNodeProp)
        {
            SequencerKeyframe* keyframe = [seqNodeProp keyframeAtTime:seq.timelinePosition];
            if (keyframe)
            {
                keyframe.value = value;
            }
            else
            {
                SequencerKeyframe* keyframe = [[[SequencerKeyframe alloc] init] autorelease];
                keyframe.time = seq.timelinePosition;
                keyframe.value = value;
                keyframe.type = type;
                
                [seqNodeProp setKeyframe:keyframe];
            }
            
            [sh redrawTimeline];
        }
        else
        {
            [nodeInfo.baseValues setObject:value forKey:propertyName];
        }
    }
}

- (BOOL) ccMouseUp:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return YES;
    
    CCNode* selectedNode = appDelegate.selectedNode;
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    if (currentMouseTransform == kCCBTransformHandleDownInside)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Add to/subtract from selection
            NSMutableArray* modifiedSelection = [NSMutableArray arrayWithArray: appDelegate.selectedNodes];
            
            if ([modifiedSelection containsObject:clickedNode])
            {
                [modifiedSelection removeObject:clickedNode];
            }
            else
            {
                [modifiedSelection addObject:clickedNode];
                //currentMouseTransform = kCCBTransformHandleMove;
            }
            appDelegate.selectedNodes = modifiedSelection;
        }
        else
        {
            // Replace selection
            [appDelegate setSelectedNodes:[NSArray arrayWithObject:clickedNode]];
            //currentMouseTransform = kCCBTransformHandleMove;
        }
        
        currentMouseTransform = kCCBTransformHandleNone;
    }
    
    if (currentMouseTransform != kCCBTransformHandleNone)
    {
        // Update keyframes & base value
        id value = NULL;
        NSString* propName = NULL;
        int type = kCCBKeyframeTypeDegrees;
        
        if (currentMouseTransform == kCCBTransformHandleRotate)
        {
            value = [NSNumber numberWithFloat: selectedNode.rotation];
            propName = @"rotation";
            type = kCCBKeyframeTypeDegrees;
        }
        else if (currentMouseTransform == kCCBTransformHandleScale)
        {
            float x = [PositionPropertySetter scaleXForNode:selectedNode prop:@"scale"];
            float y = [PositionPropertySetter scaleYForNode:selectedNode prop:@"scale"];
            value = [NSArray arrayWithObjects:
                     [NSNumber numberWithFloat:x],
                     [NSNumber numberWithFloat:y],
                     nil];
            propName = @"scale";
            type = kCCBKeyframeTypeScaleLock;
        }
        else if (currentMouseTransform == kCCBTransformHandleMove)
        {
            CGPoint pt = [PositionPropertySetter positionForNode:selectedNode prop:@"position"];
            value = [NSArray arrayWithObjects:
                     [NSNumber numberWithFloat:pt.x],
                     [NSNumber numberWithFloat:pt.y],
                     nil];
            propName = @"position";
            type = kCCBKeyframeTypePosition;
        }
        
        if (value)
        {
            [self updateAnimateablePropertyValue:value propName:propName type:type];
        }
    }
    
    if ([notesLayer mouseUp:pos event:event]) return YES;
    if ([guideLayer mouseUp:pos event:event]) return YES;
    
    isMouseTransforming = NO;
    
    if (isPanning)
    {
        [NSCursor pop];
        isPanning = NO;
    }
    
    currentMouseTransform = kCCBTransformHandleNone;
    return YES;
}

- (void)mouseMoved:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    mousePos = pos;
}

- (void)mouseEntered:(NSEvent *)event
{
    mouseInside = YES;
    
    if (!appDelegate.hasOpenedDocument) return;
    
    [rulerLayer mouseEntered:event];
}
- (void)mouseExited:(NSEvent *)event
{
    mouseInside = NO;
    
    if (!appDelegate.hasOpenedDocument) return;
    
    [rulerLayer mouseExited:event];
}

- (void)cursorUpdate:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    if (currentTool == kCCBToolGrab)
    {
        [[NSCursor openHandCursor] set];
    }
}

- (void) scrollWheel:(NSEvent *)theEvent
{
    if (!appDelegate.window.isKeyWindow) return;
    if (isMouseTransforming || isPanning || currentMouseTransform != kCCBTransformHandleNone) return;
    if (!appDelegate.hasOpenedDocument) return;
    
    int dx = [theEvent deltaX]*4;
    int dy = -[theEvent deltaY]*4;
    
    scrollOffset.x = scrollOffset.x+dx;
    scrollOffset.y = scrollOffset.y+dy;
}

#pragma mark Updates every frame

- (void) nextFrame:(ccTime) time
{
    // Recenter the content layer
    BOOL winSizeChanged = !CGSizeEqualToSize(winSize, [[CCDirector sharedDirector] winSize]);
    winSize = [[CCDirector sharedDirector] winSize];
    CGPoint stageCenter = ccp((int)(winSize.width/2+scrollOffset.x) , (int)(winSize.height/2+scrollOffset.y));
    
    self.contentSize = winSize;
    
    stageBgLayer.position = stageCenter;
    renderedScene.position = stageCenter;
    
    if (stageZoom <= 1 || !renderedScene)
    {
        // Use normal rendering
        stageBgLayer.visible = YES;
        renderedScene.visible = NO;
        [[borderDevice texture] setAntiAliasTexParameters];
    }
    else
    {
        // Render with render-texture
        stageBgLayer.visible = NO;
        renderedScene.visible = YES;
        renderedScene.scale = stageZoom;
        [renderedScene beginWithClear:0 g:0 b:0 a:1];
        [contentLayer visit];
        [renderedScene end];
        [[borderDevice texture] setAliasTexParameters];
    }
    
    [self updateSelection];
    
    // Setup border layer
    CGRect bounds = [stageBgLayer boundingBox];
    
    borderBottom.position = ccp(0,0);
    [borderBottom setContentSize:CGSizeMake(winSize.width, bounds.origin.y)];
    
    borderTop.position = ccp(0, bounds.size.height + bounds.origin.y);
    [borderTop setContentSize:CGSizeMake(winSize.width, winSize.height - bounds.size.height - bounds.origin.y)];
    
    borderLeft.position = ccp(0,bounds.origin.y);
    [borderLeft setContentSize:CGSizeMake(bounds.origin.x, bounds.size.height)];
    
    borderRight.position = ccp(bounds.origin.x+bounds.size.width, bounds.origin.y);
    [borderRight setContentSize:CGSizeMake(winSize.width - bounds.origin.x - bounds.size.width, bounds.size.height)];
    
    CGPoint center = ccp(bounds.origin.x+bounds.size.width/2, bounds.origin.y+bounds.size.height/2);
    borderDevice.position = center;
    
    // Update rulers
    origin = ccpAdd(stageCenter, ccpMult(contentLayer.position,stageZoom));
    origin.x -= stageBgLayer.contentSize.width/2 * stageZoom;
    origin.y -= stageBgLayer.contentSize.height/2 * stageZoom;
    
    [rulerLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    [rulerLayer updateMousePos:mousePos];
    
    // Update guides
    guideLayer.visible = appDelegate.showGuides;
    [guideLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    
    // Update sticky notes
    notesLayer.visible = appDelegate.showStickyNotes;
    [notesLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    
    if (winSizeChanged)
    {
        // Update mouse tracking
        if (trackingArea)
        {
            [[appDelegate cocosView] removeTrackingArea:trackingArea];
            [trackingArea release];
        }
        
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, 0, winSize.width, winSize.height) options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow  owner:[appDelegate cocosView] userInfo:NULL];
        [[appDelegate cocosView] addTrackingArea:trackingArea];
    }
    
    // Hide the transparent gui window if it has no subviews
    //if ([[appDelegate.guiView subviews] count] == 0)
    //{
    //    appDelegate.guiWindow.isVisible = NO;
    //}
}

#pragma mark Init and dealloc

-(id) initWithAppDelegate:(CocosBuilderAppDelegate*)app;
{
    appDelegate = app;
    
    nodesAtSelectionPt = [[NSMutableArray array] retain];
    
	if( (self=[super init] ))
    {
        
        [self setupEditorNodes];
        [self setupDefaultNodes];
        
        [self schedule:@selector(nextFrame:)];
        
        self.isMouseEnabled = YES;
        
        stageZoom = 1;
        
        [self nextFrame:0];
	}
	return self;
}

- (void) dealloc
{
    [trackingArea release];
    [nodesAtSelectionPt release];
	[super dealloc];
}

#pragma mark Debug


@end
