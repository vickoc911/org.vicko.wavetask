import QtQuick

import org.kde.plasma.plasmoid
import "code/CairoPenguin.js" as Penguin

Item {
    id: cairoPenguinRoot

    width: Plasmoid.configuration.iconSize * 2 / 3
    height: Plasmoid.configuration.iconSize * 2 / 3

    opacity: 0.777

    property real speed: 0.4
    property int direction: 1
    property real minX: 0
    property real maxX: 0
    property bool dockIsReady: (maxX - minX) > width

    property string currentStateName: "walker"

    property real targetX: 0
    property bool interactionLock: false
    property bool actionLock: false
    property real animationRateScale: 0.6

    function getCurrentState() {
        return Penguin.getState(currentStateName);
    }

    function setState(name) {
        if (!Penguin.isValidState(name)) {
            console.warn(`"${name}" is not a valid state!`);
            return;
        }

        currentStateName = name;

        penguinSprite.jumpTo(name);

        actionLock = getCurrentState().isOneShot();
        if (actionLock) {
            actionDoneTimer.restart();
        } else {
            actionDoneTimer.stop();
        }
    }

    function pickRandomState() {
        let next = Penguin.pickRandomAmbient();
        if (next === "") {
            return;
        }

        setState(next);

        if (getCurrentState().isMoving()) {
            targetX = minX + Math.random() * (maxX - minX);
            direction = targetX > x ? 1 : -1;
        } else {
            targetX = x;
        }
    }

    function getFrameRate(name) {
        return Penguin.getState(name)
            .getFrameRateWithScale(animationRateScale);
    }

    function stateDurationMs(name) {
        return Penguin.getState(name)
            .getDurationMs(animationRateScale);
    }

    Item {
        id: spriteContainer
        width: parent.width
        height: parent.height
        transform: Scale {
            origin.x: spriteContainer.width * 2 / 3
            origin.y: spriteContainer.height * 2 / 3
            xScale: {
                let toFaceLeft = cairoPenguinRoot.direction < 0 && cairoPenguinRoot.getCurrentState().isMoving();

                return toFaceLeft ? -1 : 1
            }
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
                frameRate: cairoPenguinRoot.getFrameRate("basher")
            }

            Sprite {
                name: "blocker"
                source: "../assets/blocker.png"
                frameCount: 6
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("blocker")
            }

            Sprite {
                name: "boarder"
                source: "../assets/boarder.png"
                frameCount: 1
                frameHeight: 30
                frameWidth: 30
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 30
                frameRate: cairoPenguinRoot.getFrameRate("boarder")
            }

            Sprite {
                name: "bomber"
                source: "../assets/bomber.png"
                frameCount: 16
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("bomber")
            }

            Sprite {
                name: "bridger"
                source: "../assets/bridger.png"
                frameCount: 15
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("bridger")
            }

            Sprite {
                name: "bridgerWalk"
                source: "../assets/bridger_walk.png"
                frameCount: 4
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("bridgerWalk")
            }

            Sprite {
                name: "digger"
                source: "../assets/digger.png"
                frameCount: 14
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("digger")
            }

            Sprite {
                name: "drownFall"
                source: "../assets/drownfall.png"
                frameCount: 15
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("drownFall")
            }

            Sprite {
                name: "drownWalk"
                source: "../assets/drownwalk.png"
                frameCount: 15
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("drownWalk")
            }

            Sprite {
                name: "exit"
                source: "../assets/exit.png"
                frameCount: 9
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("exit")
            }

            Sprite {
                name: "faller"
                source: "../assets/faller.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("faller")
            }

            Sprite {
                name: "floater"
                source: "../assets/floater.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("floater")
            }

            Sprite {
                name: "miner"
                source: "../assets/miner.png"
                frameCount: 12
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("miner")
            }

            Sprite {
                name: "reader"
                source: "../assets/reader.xpm"
                frameCount: 12
                frameHeight: 30
                frameWidth: 30
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("reader")
            }

            Sprite {
                name: "rocketLauncher"
                source: "../assets/rocketlauncher.png"
                frameCount: 7
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("rocketLauncher")
            }

            Sprite {
                name: "sitter"
                source: "../assets/sitter.png"
                frameCount: 1
                frameHeight: 30
                frameWidth: 30
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("sitter")
            }

            Sprite {
                name: "splat"
                source: "../assets/splat.png"
                frameCount: 16
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("splat")
            }

            Sprite {
                name: "superman"
                source: "../assets/superman.png"
                frameCount: 8
                frameHeight: 30
                frameWidth: 30
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("superman")
            }

            Sprite {
                name: "tumble"
                source: "../assets/tumble.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("tumble")
            }

            Sprite {
                name: "waiter"
                source: "../assets/waiter.png"
                frameCount: 6
                frameHeight: 32
                frameWidth: 32
                frameY: 0
                frameRate: cairoPenguinRoot.getFrameRate("waiter")
            }

            Sprite {
                name: "walker"
                source: "../assets/walker.png"
                frameCount: 8
                frameHeight: 32
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 32
                frameRate: cairoPenguinRoot.getFrameRate("walker")
            }

            Sprite {
                name: "xmasWalker"
                source: "../assets/xmas-walker.png"
                frameCount: 8
                frameHeight: 44
                frameWidth: 32
                frameY: cairoPenguinRoot.direction < 0 ? 0 : 44
                frameRate: cairoPenguinRoot.getFrameRate("xmasWalker")
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
            let nextAction = Penguin.pickRandomAction();
            if (nextAction) {
                cairoPenguinRoot.setState(nextAction);

                if (cairoPenguinRoot.getCurrentState().isMoving()) {
                    cairoPenguinRoot.targetX = cairoPenguinRoot.minX + Math.random() * (cairoPenguinRoot.maxX - cairoPenguinRoot.minX);
                    cairoPenguinRoot.direction = cairoPenguinRoot.targetX > cairoPenguinRoot.x ? 1 : -1;
                }
            }

            interval = 20_000 + Math.random() * 30_000;
        }
    }

    Timer {
        interval: 16
        running: cairoPenguinRoot.getCurrentState().isMoving() && !cairoPenguinRoot.interactionLock
        repeat: true
        onTriggered: {
            cairoPenguinRoot.x += (cairoPenguinRoot.speed * cairoPenguinRoot.direction)

            // 1) Comprobación de rebote antes de evaluar si llegó al objetivo.
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
        hoverEnabled: false

        onPressed: function(mouse) {
            cairoPenguinRoot.interactionLock = true
            cairoPenguinRoot.setState("bomber")

            jumpAnimation.restart()
            clickRecoveryTimer.restart()

            // Permite que el clic atraviese al pingüino para interactuar
            // con los iconos del dock que están justo debajo.
            mouse.accepted = false
        }

    }

    Timer {
        id: actionDoneTimer
        interval: cairoPenguinRoot.stateDurationMs(cairoPenguinRoot.currentStateName)
        onTriggered: {
            cairoPenguinRoot.actionLock = false;

            if (cairoPenguinRoot.currentStateName === "splat") {
                cairoPenguinRoot.interactionLock = false;
            }

            if (cairoPenguinRoot.getCurrentState().isTerminal()) {
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
