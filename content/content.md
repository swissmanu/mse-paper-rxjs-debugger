# Introduction

When software engineers look at the source code of an existing application, they want to learn about how the program was implemented technically. The engineer might do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g. during onboarding of a new team member) or, more often, because someone reported an unexpected behavior of the application (e.g. the program crashed). This kind of work is commonly known as "debugging" [@IEEE_Glossary] in the software engineering community. Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized an iterative process model (see Figure [1](#fig:debugging-process)) by dividing the broader task of debugging into three concrete steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. With the goal to prove this hypothesis, the engineer (ii) instruments the program using appropriate techniques. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

![TODO: Replace with proper graphic; Iterative Debugging Process after Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]: Gather context to formalize hypothesis, instrument hypothesis producing a modified system, and testing hypothesis resulting in a new iteration or a successfully proved hypothesis.](./content/debugging-process.png)

The most basic debugging technique for instrumentation and testing are manually added print statements to the source code: They generate extensive execution logs when placed  across the programs code and allow the reconstruction of the programs runtime behavior. once the number of generated log entries increases, the required amount of work to analyze the logs gets out of hand quickly. This is why specialized debugging utilities provide tools to interact with a program at runtime: After interrupting program execution with a breakpoint, they allow engineers to inspect stack frames, inspect and modify variables, step through successive source code statements, or resume program execution eventually. These utilities work obviously best with imperative, or control-flow oriented programming languages since they interact with the debugged program on a statement and stack frame level.

Modern IDEs enable software engineers to debug programs, no matter what programming language they are implemented with, using one, generalized user interface (UI). The result is a unified user experience where the supposed correct debugger is only a click away. Software engineers have accepted these debuggers as common practice according to Alabor et al. [@Alabor_Stolze_2020]. By integrating imperative debuggers in their workflows, software engineers face a new problem when working with reactive programming (RP) though. Alabor et al. highlight that multiple of their study participants intuitively expected their debuggers step controls to work on the RP data-flow graph, which they do not. This discrepancy between expected and actual behavior of the debugger lets engineers reportedly fall back to adding manual print statements.

Debugging RP programs with the wrong debugging utilities is not a new problem: Salvaneschi et al. described the shortcoming of traditional debuggers when confronted with RP in their paper on *RP Debugging* [@Salvaneschi_Mezini_2016_Inspector]. Further, Banken et al. [@Banken_Meijer_Gousios_2018] researched on a possible solution for debugging RxJS RP programs using an external visualizer. Up to today, no fully integrated RP debugging solution for RxJS was available though.

We are going to present our solution to this challenge in this paper: *RxJS Debugging for Visual Studio Code* is an extension for Microsoft Visual Studio Code^[https://code.visualstudio.com] which integrates RxJS-specific debugging capabilities within the IDE. By doing so, it makes manual print statements a debugging technique of the past.

Before we do a deep-dive on the extensions functionality in Section [4](#sec:implementation), we will give an example for the main challenge of reactive debugging in Section [2](#sec:challenge) and discuss the related work which lead to our solution in Section [3](#sec:related_work). Before we come to our conclusion in Section [8](#sec:conclusion), we will discuss potential Threats to Validity in Section [6](#sec:threats_to_validity) and give an overview on potential follow-up topics, research-wise as well as practical, in Section [7](#sec:future_work).

# Challenges of RP Debugging {#sec:challenge}

One of the main characteristics of RP is the paradigm shift away from imperatively formulated, control-flow oriented code (see Listing [1](#lst:imperative)), over to declarative, data-flow focused source code [CITE]. Instead of instructing the program how to do what, one step after another, we use RP abstractions to describe the transformation of a potentially continuous flow of data as shown in Listing [2](#lst:rp).

```{caption="Basic example of imperative-style/control-flow oriented programming in TypeScript: Multiply integers between 0 and 4 for every value that is smaller than 4 and call reportValue with the result." label=imperative .Typescript}
import reportValue from './reporter';

for (let i = 0; i < 5; i++) {
  if (i < 4) {
    reportValue(i * 2);
  }
}
```


```{caption="Basic RP example implemented with RxJS in TypeScript: Generate a data-flow of integers from 0 to 4, skip values equal or larger then 4, multiply these values by 2 and call reportValue with each resulting value." label=rp .Typescript}
import reportValue from './reporter';
import { of } from 'rxjs';
import { filter, map } from 'rxjs/operators';

of(0, 1, 2, 3, 4).pipe( // Flow of integers 0..4
  filter(i => i < 4),   // Omit 4
  map(i => i * 2),      // Multiply with 2
).subscribe(reportValue)
```

Once switched from an imperative to declarative programming style, the imperative debugger reaches its limitations: Where it can be used to step through the successive iterations of the *for* loop in Listing [1](#lst:imperative) as expected, this is not possible for the transformations described in Listing [2](#lst:rp): Assuming there is a breakpoint placed within the lambda function passed to *filter* on Line 6, stepping over to the next statement will not lead to the lambda of *map* on Line 7 as one might expect. Instead, the debugger will continue in the internal implementations of *filter*, which is part of the RP runtime environment. This circumstance might becomes plausible once engineers get a deeper understanding of a particular RP implementation. Alabor et al. showed nonetheless that software engineers expect a different behavior from the debugging tools they know from earlier experiences [@Alabor_Stolze_2020]. As a direct consequence, most engineers fall back to the clumsy debugging technique of adding manual print statements like in Listing [3](#lst:rp-print) to instrument their debugging hypotheses, they conclude further.

```{caption="Manually added print statements on Lines 6, 8 and 10 to debug a data-flow implemented with RxJS in TypeScript." label=rp-print .Typescript}
import reportValue from './reporter';
import { of } from 'rxjs';
import { filter, map, tap } from 'rxjs/operators';

of(0, 1, 2, 3, 4).pipe(
  tap(console.log),     // <-- Print Statement
  filter(i => i < 4),
  tap(console.log),     // <-- Print Statement
  map(i => i * 2),
  tap(console.log),     // <-- Print Statement
).subscribe(reportValue)
```


# Related Work {#sec:related_work}

- Reactive Inspector [@Salvaneschi_Mezini_2016_Inspector]
- RxFiddle [@Banken_Meijer_Gousios_2018]
- Study by Alabor et al. [@Alabor_Stolze_2020]
  - Interviews
  - Observational Study

# Extension {#sec:implementation}

- New work:
	- Prototyp
	  - Describe how it relates to the debugging process [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]
	- UX Testing of Prototype. DONT CITE [@Alabor_2020], because not peer reviewed
	- The Result: An extension for Visual Studio Code, as described in the next section:
- Demonstrate/describe Extension
  - Log Points -> Relate with probes/traces [@McDirmid_2013]

# Discussion {#sec:discussion}

- *See if necessary as distinct section or if it can be integrated within previous section instead*

# Threats to Validity {#sec:threats_to_validity}

- Usability study scope
- "only" based on [@Alabor_Stolze_2020]

# Future Work {#sec:future_work}

- Features:
	- Support for Browser-based Applications (Selling point: Angular)
	- Visualization of data flows
	- Omniscient/time travel debugging for data flows
- Research:
	- Verify if extension helps beginners to get started with RxJS
	- Verify effectiveness of extension for professionals (re-execute previous observational study)
  - More Usability Testing

# Conclusion {#sec:conclusion}

- Wrap things up
- Highlight the main contribution, again.

