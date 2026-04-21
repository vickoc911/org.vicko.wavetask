import QtQuick

import org.kde.plasma.plasmoid

Item {
    id: cairoPenguinRoot

    width: Plasmoid.configuration.iconSize * 2 / 3
    height: Plasmoid.configuration.iconSize * 2 / 3

    property real speed: 0.4
    property int direction: 1
    property real minX: 0
    property real maxX: 0
    property bool dockIsReady: (maxX - minX) > width

    property string currentState: "walker"
    property real targetX: 0
    property bool interactionLock: false
    property bool actionLock: false
    property real animationRateScale: 0.6

    readonly property list<string> movingStates: ["basher", "boarder", "bridger", "bridgerWalk", "miner", "rocketLauncher", "walker", "xmasWalker"]

    readonly property list<string> hoverWakeStates: ["sitter", "waiter", "reader", "blocker"]

    readonly property list<string> actionStates: ["bomber", "digger", "exit", "splat", "tumble"]

    readonly property list<string> oneShotStates: ["bomber", "exit", "faller", "splat", "tumble", "drownFall", "drownWalk"]

    readonly property list<string> terminalStates: ["exit", "drownFall", "drownWalk"]

    readonly property list<string> ambientStates: [...movingStates, ...hoverWakeStates]
    readonly property list<string> allStates: [...ambientStates, ...actionStates]

    readonly property var baseFrameRateByState: ({
        "basher": 12,
        "blocker": 10,
        "boarder": 1,
        "bomber": 20,
        "bridger": 15,
        "bridgerWalk": 10,
        "digger": 16,
        "drownFall": 18,
        "drownWalk": 18,
        "exit": 16,
        "faller": 8,
        "floater": 8,
        "miner": 16,
        "reader": 16,
        "rocketLauncher": 10,
        "sitter": 1,
        "splat": 20,
        "superman": 8,
        "tumble": 10,
        "waiter": 8,
        "walker": 10,
        "xmasWalker": 10
    })

    function frameRateFor(name) {
        const baseFrameRate = baseFrameRateByState[name];
        if (typeof baseFrameRate !== "number") {
            throw new Error(`Unexpected state for frame rate: ${name}`);
        }
        return baseFrameRate * animationRateScale;
    }

    function oneShotFrameSpec(name) {
        switch (name) {
        case "bomber":
            return { frameCount: 16, baseFrameRate: baseFrameRateByState.bomber };
        case "exit":
            return { frameCount: 9, baseFrameRate: baseFrameRateByState.exit };
        case "faller":
            return { frameCount: 8, baseFrameRate: baseFrameRateByState.faller };
        case "splat":
            return { frameCount: 16, baseFrameRate: baseFrameRateByState.splat };
        case "tumble":
            return { frameCount: 8, baseFrameRate: baseFrameRateByState.tumble };
        case "drownFall":
        case "drownWalk":
            return { frameCount: 15, baseFrameRate: baseFrameRateByState[name] };
        default:
            throw new Error(`Unexpected one-shot state: ${name}`);
        }
    }

    function stateDurationMs(name) {
        const spec = oneShotFrameSpec(name);
        const effectiveFrameRate = spec.baseFrameRate * animationRateScale;
        const frameMs = 1000 / effectiveFrameRate;
        const oneLoopMs = spec.frameCount * frameMs;

        // End slightly before the next loop starts.
        const safetyMarginMs = frameMs * 0.25;
        return Math.max(100, Math.floor(oneLoopMs - safetyMarginMs));
    }

    function pickRandomFrom(states) {
        if (!states || states.length === 0) {
            return "";
        }

        if (states.length === 1) {
            return states[0];
        }

        let next = currentState;
        while (next === currentState) {
            next = states[Math.floor(Math.random() * states.length)];
        }

        return next;
    }

    function setState(name) {
        if (!allStates.includes(name)) {
            return;
        }

        currentState = name;
        penguinSprite.jumpTo(name);

        actionLock = oneShotStates.includes(name);
        if (actionLock) {
            actionDoneTimer.interval = stateDurationMs(name);
            actionDoneTimer.restart();
        } else {
            actionDoneTimer.stop();
        }
    }

    function pickRandomState() {
        let next = pickRandomFrom(ambientStates);
        if (next === "") {
            return;
        }

        setState(next);

        if (movingStates.includes(next)) {
            targetX = minX + Math.random() * (maxX - minX);
            direction = targetX > x ? 1 : -1;
        } else {
            targetX = x;
        }
    }

    Item {
        id: spriteContainer
        width: parent.width
        height: parent.height
        transform: Scale {
            origin.x: spriteContainer.width * 2 / 3
            origin.y: spriteContainer.height * 2 / 3
            xScale: (cairoPenguinRoot.direction < 0 && cairoPenguinRoot.movingStates.includes(cairoPenguinRoot.currentState)) ? -1 : 1
        }

        SpriteSequence {
            id: penguinSprite
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            interpolate: false

            Sprite {
                name: "basher"
                source: "../assets/basher.png"
                frameCount: 12
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("basher")
            }

            Sprite {
                name: "blocker"
                source: "../assets/blocker.png"
                frameCount: 6
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("blocker")
            }

            Sprite {
                name: "boarder"
                source: "../assets/boarder.png"
                frameCount: 1
                frameHeight: 30
                frameWidth: 30
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 30
                frameRate: cairoPenguinRoot.frameRateFor("boarder")
            }

            Sprite {
                name: "bomber"
                source: "../assets/bomber.png"
                frameCount: 16
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("bomber")
            }

            Sprite {
                name: "bridger"
                source: "../assets/bridger.png"
                frameCount: 15
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("bridger")
            }

            Sprite {
                name: "bridgerWalk"
                source: "../assets/bridger_walk.png"
                frameCount: 4
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("bridgerWalk")
            }

            Sprite {
                name: "digger"
                source: "../assets/digger.png"
                frameCount: 14
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("digger")
            }

            Sprite {
                name: "drownFall"
                source: "../assets/drownfall.png"
                frameCount: 15
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("drownFall")
            }

            Sprite {
                name: "drownWalk"
                source: "../assets/drownwalk.png"
                frameCount: 15
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("drownWalk")
            }

            Sprite {
                name: "exit"
                source: "../assets/exit.png"
                frameCount: 9
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("exit")
            }

            Sprite {
                name: "faller"
                source: "../assets/faller.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("faller")
            }

            Sprite {
                name: "floater"
                source: "../assets/floater.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("floater")
            }

            Sprite {
                name: "miner"
                source: "../assets/miner.png"
                frameCount: 12
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("miner")
            }

            Sprite {
                name: "reader"
                source: "../assets/reader.xpm"
                frameCount: 12
                frameHeight: 30
                frameWidth: 30
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("reader")
            }

            Sprite {
                name: "rocketLauncher"
                source: "../assets/rocketlauncher.png"
                frameCount: 7
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("rocketLauncher")
            }

            Sprite {
                name: "sitter"
                source: "../assets/sitter.png"
                frameCount: 1
                frameHeight: 30
                frameWidth: 30
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("sitter")
            }

            Sprite {
                name: "splat"
                source: "../assets/splat.png"
                frameCount: 16
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("splat")
            }

            Sprite {
                name: "superman"
                source: "../assets/superman.png"
                frameCount: 8
                frameHeight: 30
                frameWidth: 30
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("superman")
            }

            Sprite {
                name: "tumble"
                source: "../assets/tumble.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("tumble")
            }

            Sprite {
                name: "waiter"
                source: "../assets/waiter.png"
                frameCount: 6
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.frameRateFor("waiter")
            }

            Sprite {
                name: "walker"
                source: "../assets/walker.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.frameRateFor("walker")
            }

            Sprite {
                name: "xmasWalker"
                source: "../assets/xmas-walker.png"
                frameCount: 8
                frameHeight: 44
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 44
                frameRate: cairoPenguinRoot.frameRateFor("xmasWalker")
            }
        }
    }

    Timer {
        interval: 7000 + Math.random() * 15_000
        running: cairoPenguinRoot.dockIsReady && !cairoPenguinRoot.interactionLock && !cairoPenguinRoot.actionLock
        repeat: true
        onTriggered: cairoPenguinRoot.pickRandomState()
    }

    Timer {
        interval: 20_000 + Math.random() * 30_000
        running: cairoPenguinRoot.dockIsReady && !cairoPenguinRoot.interactionLock && !cairoPenguinRoot.actionLock
        repeat: true
        onTriggered: {
            let nextAction = cairoPenguinRoot.pickRandomFrom(cairoPenguinRoot.actionStates);
            if (nextAction !== "") {
                cairoPenguinRoot.setState(nextAction);
                if (cairoPenguinRoot.movingStates.includes(nextAction)) {
                    cairoPenguinRoot.targetX = cairoPenguinRoot.minX + Math.random() * (cairoPenguinRoot.maxX - cairoPenguinRoot.minX);
                    cairoPenguinRoot.direction = cairoPenguinRoot.targetX > cairoPenguinRoot.x ? 1 : -1;
                }
            }

            interval = 20_000 + Math.random() * 30_000;
        }
    }

    Timer {
        interval: 16
        running: cairoPenguinRoot.movingStates.includes(cairoPenguinRoot.currentState) && !cairoPenguinRoot.interactionLock
        repeat: true
        onTriggered: {
            cairoPenguinRoot.x += (cairoPenguinRoot.speed * cairoPenguinRoot.direction)

            // 1. THE BOUNCE CHECK (Do this before checking if he reached his target)
            if (cairoPenguinRoot.x >= cairoPenguinRoot.maxX) {
                cairoPenguinRoot.x = cairoPenguinRoot.maxX
                cairoPenguinRoot.direction = -1;

                cairoPenguinRoot.targetX = cairoPenguinRoot.minX + Math.random() * (cairoPenguinRoot.x - cairoPenguinRoot.minX)
                return;
            }

            if (cairoPenguinRoot.x <= cairoPenguinRoot.minX) {
                cairoPenguinRoot.x = cairoPenguinRoot.minX
                cairoPenguinRoot.direction = 1;

                cairoPenguinRoot.targetX = cairoPenguinRoot.x + Math.random() * (cairoPenguinRoot.maxX - cairoPenguinRoot.x)
                return;
            }

            let movesRight = cairoPenguinRoot.direction === 1
            let reachedFromRight = cairoPenguinRoot.x >= cairoPenguinRoot.targetX
            let reachedFromLeft = cairoPenguinRoot.x <= cairoPenguinRoot.targetX
            let reachedTarget = (movesRight && reachedFromRight) || (!movesRight && reachedFromLeft)

            if (reachedTarget) {
                cairoPenguinRoot.x = cairoPenguinRoot.targetX
                cairoPenguinRoot.pickRandomState()
            }
        }
    }

    onDockIsReadyChanged: {
        if (dockIsReady) {
            cairoPenguinRoot.x = cairoPenguinRoot.minX
            cairoPenguinRoot.targetX = cairoPenguinRoot.x
            cairoPenguinRoot.pickRandomState()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: false

        onPressed: function(mouse) {
            cairoPenguinRoot.interactionLock = true
            cairoPenguinRoot.setState("bomber")

            jumpAnimation.restart()
            clickRecoveryTimer.restart()

            mouse.accepted = false
        }

        onEntered: {
            if (!cairoPenguinRoot.interactionLock && cairoPenguinRoot.hoverWakeStates.includes(cairoPenguinRoot.currentState)) {
                cairoPenguinRoot.pickRandomState()
            }
        }
    }

    Timer {
        id: actionDoneTimer
        interval: 1000
        onTriggered: {
            cairoPenguinRoot.actionLock = false;
            if (cairoPenguinRoot.terminalStates.includes(cairoPenguinRoot.currentState)) {
                spriteContainer.visible = false;
                cairoPenguinRoot.interactionLock = true;
                respawnTimer.restart();
            } else if (!cairoPenguinRoot.interactionLock) {
                cairoPenguinRoot.pickRandomState();
            }
        }
    }

    Timer {
        id: respawnTimer
        interval: 5000 + Math.random() * 10_000
        onTriggered: {
            cairoPenguinRoot.x = cairoPenguinRoot.minX + Math.random() * (cairoPenguinRoot.maxX - cairoPenguinRoot.minX);

            spriteContainer.visible = true;
            cairoPenguinRoot.interactionLock = false;

            cairoPenguinRoot.pickRandomState();
        }
    }

    Timer {
        id: clickRecoveryTimer
        interval: 1200
        onTriggered: {
            cairoPenguinRoot.setState("splat")
            postClickTimer.interval = cairoPenguinRoot.stateDurationMs("splat")
            postClickTimer.restart()
        }
    }

    Timer {
        id: postClickTimer
        interval: 2000
        onTriggered: {
            cairoPenguinRoot.interactionLock = false
            cairoPenguinRoot.pickRandomState()
        }
    }

    SequentialAnimation {
        id: jumpAnimation

        NumberAnimation {
            target: spriteContainer
            property: "y"
            from: 0
            to: -40
            duration: 800
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: spriteContainer
            property: "y"
            to: 0
            duration: 400
            easing.type: Easing.InQuad
        }
    }
}
