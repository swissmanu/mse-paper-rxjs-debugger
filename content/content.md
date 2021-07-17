# Introduction

Software development consists of two parts: The first part is about creating novel applications, about the creative process [CITE] of building solutions to specific problems [CITE]. The other part is about understanding the behavior, source code and composition of existing programs [CITE]. All software engineer begin to develop the second skill once they start improving their programming abilities: Right from the point where they read their first "Hello World" code example, they start to build an intuition on how a computer might interpret and execute a given piece of source code. Once things get more involved, simply "thinking" *(mentally exercising? other formulation?)* through source code might not suffice anymore: A common technique to trace the runtime behavior of a program is the manual introduction of print statements to the source code. Multiple such statements, placed at key turning points of the program, generate extensive execution logs allowing to reconstruct the programs runtime behavior. Analyzing large amounts of logs is tedious work. Specialized debugging utilities provide more sophisticated tools to inspect programs at runtime: A breakpoint on a statement interrupts program execution. Once halted, engineers can inspect and modify variables in a stack frame, step through successive source code statements and eventually even resume normal program execution.



- Nice: Previous work showed its possible [@Salvaneschi_Mezini_2016_Inspector]
- Why not for RxJS?
- Previous work tried: for visual debugging [@Banken_Meijer_Gousios_2018]
- Previous work showed that RxJS reactive debugging still sucks: [@Alabor_Stolze_2020]
- State of The Art is: Debugging with console.log Statements
- Our contribution:
  - A (partial) answer to the third research question by [@Alabor_Stolze_2020]
    - RQ2: How can the experience of software engineers dur-ing the debugging process of RxJS-based applications beimproved?
    - RQ3: What is the impact of proposed solutions on thedebugging experience of software engineers?
  - We have a solution: Integrated, reactive debugging
  - Our contribution is an iteration on the topic of debugging for RxJS applications
  - Debug without console.log
  - Integration of reactive debugging in an IDE: Visual Studio Code
- Content of this paper:
  - Related work
  - Our work on the topic
  - Feature Demonstration
  - Future Work


# Related Work {#sec:related_work}

- [@Salvaneschi_Mezini_2016_Inspector]
- [@Banken_Meijer_Gousios_2018]
- Previous Work [@Alabor_Stolze_2020]
  - Interviews
  - Observational Study

# Research {#sec:research}

- New work:
	- Prototyp
	  - Describe how it relates to the debugging process [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]
	- UX Testing of Prototype [@Alabor_2020]
	- The Result: An extension for Visual Studio Code, as described in the next section:

# Implementation {#sec:implementation}

- Demonstrate/describe Extension
  - Log Points -> Relate with probes/traces [@McDirmid_2013]
- *Idea: Can we demonstrate somehow an example with hot code reloading, so we have a better "live" experience?*

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

