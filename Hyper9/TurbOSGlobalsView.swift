//
//  TurbOSGlobalsView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/22/25.
//

import SwiftUI

struct TurbOSGlobalsView: View {
    @EnvironmentObject var model: Turbo9ViewModel
    
    var body: some View {
        GroupBox {
            HStack {
                VStack {
                    LabeledHex16TextField(label: "D.FMBM (Start):", number: $model.turbo9.D_FMBM_Start,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    LabeledHex16TextField(label: "D.FMBM (End):", number: $model.turbo9.D_FMBM_End,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.MLIM:", number: $model.turbo9.D_MLIM,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.ModDir (Start):", number: $model.turbo9.D_ModDir_Start,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.ModDir (End):", number: $model.turbo9.D_ModDir_End,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.Init:", number: $model.turbo9.D_Init,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SWI3:", number: $model.turbo9.D_SWI3,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SWI2:", number: $model.turbo9.D_SWI2,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.FIRQ:", number: $model.turbo9.D_FIRQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.IRQ:", number: $model.turbo9.D_IRQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SWI:", number: $model.turbo9.D_SWI,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.NMI:", number: $model.turbo9.D_NMI,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.NMI:", number: $model.turbo9.D_NMI,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SvcIRQ:", number: $model.turbo9.D_SvcIRQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.Poll:", number: $model.turbo9.D_Poll,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.UsrIRQ:", number: $model.turbo9.D_UsrIRQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.UsrSvc:", number: $model.turbo9.D_UsrSvc,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SysSvc:", number: $model.turbo9.D_SysSvc,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.UsrDis:", number: $model.turbo9.D_UsrDis,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex8TextField(label: "D.Slice:", number: $model.turbo9.D_Slice,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SysDis:", number: $model.turbo9.D_SysDis,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.PrcDBT:", number: $model.turbo9.D_PrcDBT,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.Proc:", number: $model.turbo9.D_Proc,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.AProcQ:", number: $model.turbo9.D_AProcQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.WProcQ:", number: $model.turbo9.D_WProcQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.SProcQ:", number: $model.turbo9.D_SProcQ,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Year:", number: $model.turbo9.D_Year,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Month:", number: $model.turbo9.D_Month,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Day:", number: $model.turbo9.D_Day,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Hour:", number: $model.turbo9.D_Hour,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Min:", number: $model.turbo9.D_Min,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Sec:", number: $model.turbo9.D_Sec,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex16TextField(label: "D.Ticks (High):", number: $model.turbo9.D_Ticks_High,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.Ticks (Low):", number: $model.turbo9.D_Ticks_Low,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Tick:", number: $model.turbo9.D_Tick,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.TSec:", number: $model.turbo9.D_TSec,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.TSlice:", number: $model.turbo9.D_TSlice,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.IOML:", number: $model.turbo9.D_IOML,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.IOMH:", number: $model.turbo9.D_IOMH,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.DevTbl:", number: $model.turbo9.D_DevTbl,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.PolTbl:", number: $model.turbo9.D_PolTbl,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.PthDBT:", number: $model.turbo9.D_PthDBT,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.BTLO:", number: $model.turbo9.D_BTLO,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.BTHI:", number: $model.turbo9.D_BTHI,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.Clock:", number: $model.turbo9.D_Clock,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.Boot:", number: $model.turbo9.D_Boot,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LabeledHex16TextField(label: "D.UrToSs:", number: $model.turbo9.D_UrToSs,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex16TextField(label: "D.VIRQTable:", number: $model.turbo9.D_VIRQTable,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledHex8TextField(label: "D.CRC:", number: $model.turbo9.D_CRC,
                                          labelWidth: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                }
            }
        } label: {
            Label("System Globals", systemImage: "text.page")
        }
    }
}

#Preview {
    TurbOSGlobalsView()
}
