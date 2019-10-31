import Data.Monoid

import Graphics.X11.ExtraTypes.XF86

import XMonad
import XMonad.Actions.CycleWS
import XMonad.Config.Azerty
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Layout.FixedColumn
import XMonad.Layout.NoBorders
import XMonad.Layout.Spacing
import XMonad.Util.Run

import qualified XMonad.Actions.FlexibleResize as Flex
import qualified Data.List as L
import qualified Data.Map as M
import qualified XMonad.StackSet as W


xmobarConfig = "/etc/xmde/xmobar.conf"
xmenuConfig  = "/etc/xmde/xmenu.conf"
wallpaperDir = "/usr/share/wallpaper"


main = do
  spawn "xmde-highlight"
  spawn ( "xmde-wallpaper " ++ wallpaperDir )
  xmobar <- spawnPipe ( "xmobar " ++ xmobarConfig )
  xmonad $ ewmh azertyConfig
    { keys               = xmdeKeyControls
    , mouseBindings      = xmdeMouseControls
    , normalBorderColor  = colorNormalBorder
    , focusedBorderColor = colorFocusedBorder
    , layoutHook         = xmdeLayout
    , logHook            = dynamicLogWithPP $ xmdeXmobarPP xmobar
    , manageHook         = xmdeManage
    , handleEventHook    = xmdeEvent
    }


xmdeLayout = avoidStruts
  ( smartBorders ( FixedColumn 1 20 80 10 ) |||
    noBorders Full
  )

xmdeManage = composeAll
  [ manageDocks
  , isFullscreen --> doFullFloat
  ]

xmdeEvent = handleEventHook azertyConfig
            <+> fullscreenEventHook
            <+> docksEventHook


-- ----------------------------------------------------------------------------
-- Colors and theme related stuff

colorNormalBorder = "#101010"
colorFocusedBorder = "#cccccc"


-- ----------------------------------------------------------------------------
-- Controls for keyboard and mouse

xmdeKeyControls conf@(XConfig { XMonad.modMask= modMask }) = M.fromList $
  -- Applications quick launch and controls
  [ (( mod4Mask, xK_a ), spawn ( "xmde-appmenu "    ++ xmenuConfig ) )
  , (( mod4Mask, xK_d ), spawn ( "xmde-docmenu "    ++ xmenuConfig ) )
  , (( mod4Mask, xK_s ), spawn ( "xmde-screenmenu "                ) )
  , (( mod4Mask, xK_q ), kill )
  , (( mod4Mask, xK_t ), spawn "urxvt" )

  , (( 0, xF86XK_AudioMute),        spawn "xmde-volume mute" )
  , (( 0, xF86XK_AudioLowerVolume), spawn "xmde-volume down" )
  , (( 0, xF86XK_AudioRaiseVolume), spawn "xmde-volume up" )
    
  , (( 0, xF86XK_AudioPlay),        spawn "mpc toggle")
  , (( 0, xF86XK_AudioStop),        spawn "mpc stop")
  , (( 0, xF86XK_AudioNext),        spawn "mpc next")
  , (( 0, xF86XK_AudioPrev),        spawn "mpc prev")

  , (( 0, xK_Print ),               spawn "scrot" )
  , (( 0, xF86XK_Display),          spawn "xmde-screenmenu switch")
    
  -- Windows navigation and layout settings
  , (( modMask,  xK_Tab ),  windows W.focusDown )
  , (( mod4Mask, xK_Tab ),  windows W.swapDown )
  , (( mod4Mask, xK_f ),    fullFloatFocused )
  , (( mod4Mask, xK_g ),    stopFloatFocused )
  , (( mod4Mask, xK_space), sendMessage NextLayout )


  -- Workspaces navigation and windows relocation
  , (( mod4Mask, xK_Left ),               prevMSWS )
  , (( mod4Mask, xK_Right ),              nextMSWS )
  , (( mod4Mask, xK_Up),                  nextScreen )
  , (( mod4Mask, xK_Down),                prevScreen )
  , (( mod4Mask .|. shiftMask, xK_Left),  shiftPrevMSWS >> prevMSWS )
  , (( mod4Mask .|. shiftMask, xK_Right), shiftNextMSWS >> nextMSWS )
  , (( mod4Mask .|. shiftMask, xK_Up),    swapNextScreen >> nextScreen)
  , (( mod4Mask .|. shiftMask, xK_Down),  swapPrevScreen >> prevScreen)

  -- Main controls over machine and GUI
  , (( controlMask .|. mod4Mask, xK_x ), spawn "xmde-restart" )
  , (( mod4Mask, xK_l ), spawn "xmde-lock" )
  ]

xmdeMouseControls (XConfig {XMonad.modMask = modMask}) = M.fromList $
  -- Move windows with left click
  [ ((mod4Mask, button1), (\w -> focus w >> mouseMoveWindow w >> windows W.shiftMaster))
  -- Resize windows with right click
  , ((mod4Mask, button3), (\w -> focus w >> Flex.mouseResizeWindow w))
  ]
  


-- ----------------------------------------------------------------------------
-- Helper functions

fullFloatFocused =
  withFocused $ \f -> windows =<< appEndo `fmap` runQuery doFullFloat f
stopFloatFocused =
  withFocused $ \f -> windows =<< appEndo `fmap` runQuery doNoFloat f
  where doNoFloat = ask >>= doF . W.sink

onMainScreen :: X (WindowSpace -> Bool)
onMainScreen = do ws <- gets windowset
                  let allws = map W.tag (W.workspaces ws)
                      visws = map (W.tag . W.workspace) (W.visible ws)
                      curvs = W.tag (W.workspace (W.current ws))
                      unvws = [curvs] ++ (allws L.\\ visws)
                  return (inner unvws)
  where inner mid ws = (W.tag ws) `elem` mid

nextMSWS      = moveTo  Next (WSIs onMainScreen)
prevMSWS      = moveTo  Prev (WSIs onMainScreen)
shiftNextMSWS = shiftTo Next (WSIs onMainScreen)
shiftPrevMSWS = shiftTo Prev (WSIs onMainScreen)

xmdeXmobarPP p = defaultPP
  { ppCurrent         = \_ -> "<icon=workspace/ws-focused.xpm/>"
  , ppVisible         = \_ -> "<icon=workspace/ws-screen.xpm/>"
  , ppHidden          = \_ -> "<icon=workspace/ws-active.xpm/>"
  , ppHiddenNoWindows = \_ -> "<icon=workspace/ws-inactive.xpm/>"
  , ppUrgent          = \_ -> "<icon=workspace/ws-focused.xpm/>"
  , ppWsSep           = ""
  , ppSep             = " "
  , ppOrder           = \(ws:_:t:_) -> [ws, t]
  , ppOutput          = hPutStrLn p
  }
