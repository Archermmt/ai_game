"""Fit the physical camera to the four marked turf corners of the reference."""
import json
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

ROOT = Path(__file__).resolve().parents[2]
TARGET = np.array([[190,155],[735,186],[765,471],[85,411]], dtype=float)
CORNERS = np.array([[-12,0,-8],[12,0,-8],[12,0,8],[-12,0,8]])
CENTER = np.array([426.,240.])

def axes(yaw, pitch, roll):
    right = np.array([np.cos(yaw),0.,-np.sin(yaw)])
    up = np.array([-np.sin(yaw)*np.sin(pitch),np.cos(pitch),-np.cos(yaw)*np.sin(pitch)])
    back = np.cross(right, up)
    return np.array([right*np.cos(roll)+up*np.sin(roll), up*np.cos(roll)-right*np.sin(roll), back])

def project(params, points, perspective):
    yaw,pitch,roll,distance,scale,sx,sy = params
    view = points @ axes(yaw,pitch,roll).T
    xy = view[:,:2] - [sx,sy]
    px = xy * [1,-1] * scale
    if perspective:
        px = px / (1-view[:,2:3]/distance)
    return px + CENTER

def fit(perspective):
    residual = lambda p: (project(p, CORNERS, perspective)-TARGET).flatten()
    sol = least_squares(residual,[.1,.72,0,53,25,0,0],bounds=([-1,.2,-.2,22,10,-8,-8],[1,1.4,.2,180,65,8,8]))
    return sol.x, float(np.sqrt(np.mean(residual(sol.x)**2)))

if __name__ == '__main__':
    p,err = fit(True)
    print('pixel RMS by coordinate, perspective / orthographic:',err,fit(False)[1])
    yaw,pitch,roll,dist,scale,sx,sy = p
    basis = axes(yaw,pitch,roll)
    dump = dict(position=([sx,sy,dist] @ basis).tolist(),basis=basis.tolist(),fov=float(np.degrees(2*np.arctan(240/(dist*scale)))),perspective_fit_rms_px=err,ortho_fit_rms_px=fit(False)[1])
    (ROOT/'street/rendering/camera_fit.json').write_text(json.dumps(dump,indent=2)+'\n')
    print(dump)
