//
//  MatchLayer.m
//  WizardWar
//
//  Created by Sean Hess on 5/17/13.
//  Copyright (c) 2013 The LAB. All rights reserved.
//

#import "MatchLayer.h"
#import "cocos2d.h"
#import "MatchGroundSprite.h"
#import "WizardSprite.h"
#import "Match.h"
#import "Spell.h"
#import "SpellSprite.h"
#import "NSArray+Functional.h"
#import "NSArray+Functional.h"
#import "Elements.h"

#import "SimpleAudioEngine.h"
#import "SpellFireball.h"
#import "SpellEarthwall.h"
#import "SpellBubble.h"
#import "SpellMonster.h"
#import "SpellVine.h"
#import "SpellWindblast.h"
#import "SpellIcewall.h"
#import "NSArray+Functional.h"
#import "LifeManaIndicatorNode.h"

#import <ReactiveCocoa.h>

#define INDICATOR_PADDING_X 150
#define INDICATOR_PADDING_Y 20

@interface MatchLayer () <CCTouchOneByOneDelegate, MatchDelegate>
@property (nonatomic, strong) Match * match;
@property (nonatomic, strong) Units * units;
@property (nonatomic, strong) CCLayer * spells;
@property (nonatomic, strong) CCLayer * players;
@property (nonatomic, strong) CCLayer * indicators;

@property (nonatomic, strong) NSString * matchId;

@property (nonatomic, strong) CCSprite * message;
@property (nonatomic, strong) CCSprite * background;

@property (nonatomic, strong) CCLabelTTF * debug;

@property (nonatomic, strong) UIButton * backButton;

@end

@implementation MatchLayer

-(id)initWithMatch:(Match*)match size:(CGSize)size {
    if ((self = [super init])) {
        // background
        self.background = [CCSprite spriteWithFile:@"background-cave.png"];
        self.background.anchorPoint = ccp(0,0);
        [self addChild:self.background];
        
        // match
        // TODO: MatchLayer should create match if it is the delegate
        self.match = match;
        self.match.delegate = self;
        
        [[RACAble(self.match.status) distinctUntilChanged] subscribeNext:^(id value) {
            [self renderMatchStatus];
        }];
        
        
        self.players = [CCLayer node];
        [self addChild:self.players];
        
        self.spells = [CCLayer node];
        [self addChild:self.spells];
        
        self.indicators = [CCLayer node];
        [self addChild:self.indicators];
        
        CGFloat zeroY = 100;
        CGFloat wizardOffset = 75;
        self.units = [[Units alloc] initWithZeroY:zeroY min:wizardOffset max:size.width-wizardOffset];
        
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"messages.plist"];
        
        self.message = [[CCSprite alloc] initWithSpriteFrameName:@"msg-ready.png"];
        self.message.position = ccp(size.width/2, size.height/2);
        [self addChild:self.message];
        
        // LIFE MANA INDICATORS add two of them to the right spot
        LifeManaIndicatorNode * player1Indicator = [LifeManaIndicatorNode node];
        LifeManaIndicatorNode * player2Indicator = [LifeManaIndicatorNode node];
        
        player1Indicator.position = ccp(INDICATOR_PADDING_X, size.height - INDICATOR_PADDING_Y);
        player2Indicator.position = ccp(size.width - INDICATOR_PADDING_X, size.height - INDICATOR_PADDING_Y);
        
        [self.indicators addChild:player1Indicator];
        [self.indicators addChild:player2Indicator];
        
        [self.match connect];
        [self scheduleUpdate];
        
        
        // DEBUG THING
//        self.debug = [CCLabelTTF labelWithString:@"0" fontName:@"Marker Felt" fontSize:120];
//        self.message.visible = NO;
//        self.debug.position = self.message.position;
//        [self addChild:self.debug];
    }
    return self;
}

- (void)onExit {
    NSLog(@"MatchLayer: onExit");
}

-(void)update:(ccTime)delta {
    //    NSLog(@"Updated %f", delta);
    
    // need to update each one
    [self.match update:delta];
}

#pragma mark -  MATCH DELEGATE

-(void)didRemoveSpell:(Spell *)spell {
    SpellSprite * sprite = [NSArray array:self.spells.children find:^BOOL(SpellSprite * sprite) {
        return (sprite.spell == spell);
    }];
    [self.spells removeChild:sprite];
}

-(void)didAddSpell:(Spell *)spell {
    SpellSprite * sprite = [[SpellSprite alloc] initWithSpell:spell units:self.units];
    [self.spells addChild:sprite];
    
    if([spell isMemberOfClass: [SpellFireball class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"fireball.wav"];//play a sound
    } else if([spell isMemberOfClass: [SpellEarthwall class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"earthwall.wav"];//play a sound
    } else if([spell isMemberOfClass: [SpellVine class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"vine.wav"];//play a sound
    } else if([spell isMemberOfClass: [SpellBubble class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"bubble.wav"];//play a sound
    } else if([spell isMemberOfClass: [SpellIcewall class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"icewall.wav"];//play a sound
    } else if([spell isMemberOfClass: [SpellMonster class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"monster.wav"];//play a sound
    } else if([spell isMemberOfClass: [SpellWindblast class]]){
        [[SimpleAudioEngine sharedEngine] playEffect:@"windblast.wav"];//play a sound
    }
}

- (void)didAddPlayer:(Player *)player {
    WizardSprite * wizard = [[WizardSprite alloc] initWithPlayer:player units:self.units];
    [self.players addChild:wizard];
    NSLog(@"ADDED PLAYER %@", player);
}

- (void)didRemovePlayer:(Player *)player {
    WizardSprite * sprite = [NSArray array:self.players.children find:^BOOL(WizardSprite * sprite) {
        return (sprite.player == player);
    }];
    [self.players removeChild:sprite];
    // Someone disconnected
}

- (void)didTick:(NSInteger)currentTick {
    self.debug.string = [NSString stringWithFormat:@"%i", (int)(currentTick * TICK_INTERVAL)];
}

- (void)renderMatchStatus {
    self.message.visible = (self.match.status == MatchStatusReady || self.match.status == MatchStatusEnded);
    self.players.visible = (self.match.status == MatchStatusPlaying || self.match.status == MatchStatusEnded);
    
    if (self.match.status == MatchStatusPlaying) {
        // assign players to indicators
        NSArray * players = self.match.sortedPlayers;
        [players forEachIndex:^(int i) {
            // view can data-bind to player
            LifeManaIndicatorNode * node = [self.indicators.children objectAtIndex:i];
            Player * player = players[i];
            node.player = player;
        }];
    }
    
    if (self.match.status == MatchStatusEnded) {
        NSString * messageFrameName = nil;
        if (self.match.currentPlayer.state == PlayerStateDead)
            messageFrameName = @"msg-you-lose.png";
        else
            messageFrameName = @"msg-you-won.png";
        [self.message setDisplayFrame:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:messageFrameName]];
    }
}

- (void)dealloc {
    NSLog(@"MatchLayer: dealloc%@", self);
}

@end
